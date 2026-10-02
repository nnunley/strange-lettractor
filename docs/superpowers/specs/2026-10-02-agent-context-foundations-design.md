# Agent context foundations

Status: split on 2026-10-02 from the dispatch-loop design
(`2026-10-01-dispatch-loop-context-design.md`), which depends on it.
Implementation planning has not started. It has no prerequisites.

## Problem

An agent stage's context grows without bound and fails at the provider with no
record of why. Every tool result enters history, truncated only per call
(`read_file` keeps 50,000 characters). `check-context-usage!` warns once, and
`recover-context-overflow!` only returns the session to idle.

On 2026-10-01 the let-go research loop's `propose` stage, running
`qwen3.8-27b` on llama.cpp with a 131,072-token window, sent a 139,495-token
request and failed. Pipeline agent stages save only `prompt.md`, `response.md`
and `status.json`, so which reads filled the context is unknown.

## Outcome

Every agent stage leaves a full transcript. A request that would exceed the
window fails before it is sent, with the numbers. A node can restrict its agent
to named tools, and an agent can page through large raw files on disk.

Each piece below is useful on its own and ships as its own PR. The dispatch
loop uses all of them.

## 1. Transcripts

A `:transcript_path` session option attaches an `:on_event` writer that appends
each session event to a JSONL file, one event per line.

- The `:tool_call_end` event already carries the untruncated tool output
  (`agent.lg` `execute-single-tool`, before `truncate-tool-output`), so the
  transcript holds full tool results without capturing anything twice.
- The codergen handler sets the path to `<stage-dir>/transcript.jsonl` for every
  agent stage. The stage directory reaches the session through
  `:tool_hook_context` (`handlers.lg` `make-codergen-handler`).
- A write failure emits a `:warning` event and stops the writer; it never fails
  the stage.

## 2. Usage event

After each model call, emit `:usage` with `:input_tokens`, `:output_tokens`,
and the cache read/write counts when the provider reports them. Today usage is
stored only on the assistant turn, where nothing but `sum-usage-tokens` reads
it.

## 3. Pre-send backstop

Before each request, estimate its size:

- the last provider-reported input tokens (cache reads and writes included),
  plus characters/4 for history added since that request;
- characters/4 for the whole history when no report exists yet.

Add `:context_reserve_tokens` (default 8192). If the total exceeds the known
window, fail with a `:context-length` error before calling the provider; the
error names the estimate, the reserve and the window. Otherwise clamp the
request's output-token limit to the remaining headroom. When the window is
unknown, the backstop does nothing.

There is no compaction: the request fails early instead of failing at the
provider.

## 4. Per-node tool allowlist

Attractor's own agent nodes cannot restrict their tools today; `--tools` exists
only for the external `claude` worker. A `--tools` node attribute (comma list)
removes every other tool from the session's registry at creation. A call to a
removed tool is a tool error. An unknown name in the list fails the node at
start.

## 5. `read_handle`

`read_handle(path, offset, limit)` pages through a file under the current run's
logs root, by lines. A path outside the logs root is a tool error. It is
registered like the subagent tools (`agent.lg` `register-subagent-tools!`).

## Configuration

`session_options_fn` for agent nodes reads these node attributes, which a
`model_stylesheet` class can set. The integer parser moves out of
`task_review_bindings.lg` into a shared place.

| Attribute | Session option | Default |
|---|---|---|
| `--context-window` | `:context_window_size` (existing) | discovered |
| `--context-reserve-tokens` | `:context_reserve_tokens` | 8192 |
| `--tools` | tool allowlist | all |

Transcripts need no attribute.

## Tests

Offline, scripted through `:complete_fn` or the mock adapter:

1. `transcript.jsonl` holds the user input, the tool call, the untruncated tool
   output, the assistant turn and `:usage` events, in order.
2. A transcript write failure warns and the stage completes.
3. With a tiny window and large history, the backstop raises `:context-length`
   and the mock records zero provider calls.
4. The estimate uses the last reported input tokens plus characters/4 for newer
   history, and the output-token limit is clamped to the remaining headroom.
5. An unknown window disables the backstop.
6. A `--tools` session has only the named tools; calling another is a tool
   error; an unknown name fails at start.
7. `read_handle` pages by offset and limit, and refuses a path outside the logs
   root.
8. Node attributes from a stylesheet reach the session options.

Live, opt-in (skipped without the server): rerun the research loop's `propose`
on `qwen3.8-27b` and check that its transcript shows which reads grew the
context and that the backstop fails it before the provider does.

## Out of scope

- The dispatch loop (its own spec).
- Summarizing tool results or compacting history inside a session.
- Token budgets and turn limits per node (the stylesheet constraints design).

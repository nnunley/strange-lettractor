# Dispatch loop: bounded context for long agent stages

Status: design approved in conversation on 2026-10-01; implementation planning
has not started. Stage 1 (workflow fragment) is specified here; stage 2 (an
in-session strategy) gets its own short spec later.

## Problem

An agent stage's context grows without bound. Every tool result enters history,
truncated only per call (`read_file` keeps 50,000 characters), and nothing
compacts history: `check-context-usage!` warns once, and
`recover-context-overflow!` only returns the session to idle. A long stage
therefore fails at the provider with a context-length error.

The let-go research loop showed this twice on 2026-10-01. Its `propose` stage,
running `qwen3.8-27b` on llama.cpp with a 131,072-token window, sent a
139,495-token request and failed, even with a prompt rule limiting reads to 400
lines and steering large-file questions to `spawn_agent`. Prompt rules alone do
not bound the context of this model.

The failure could not be diagnosed either: pipeline agent stages save only
`prompt.md`, `response.md` and `status.json`, so which reads filled the context
is unknown.

## Outcome

A long agent task runs as a loop of fresh, bounded turns. No single model request
can exceed its window by construction, every turn is fully recorded, and only a
coding-agent turn changes code.

## Selected approach

Each turn dispatches a fresh agent session with a fixed budget. A tool-free
summarizer folds the turn's result into a capped state document, and only that
document carries forward. Raw outputs stay on disk as handles.

Considered and set aside: summarizing large tool results inside one long-lived
session and compacting its history under pressure. That bounds context by
estimation and recovery; the dispatch loop bounds it by construction. The
transcript and pre-send backstop from that design are kept.

Stage 1 builds the loop as a workflow fragment. Stage 2 adds
`:context_strategy :dispatch` to agent sessions, reusing the same state schema
and turn files.

## The loop

```
plan → dispatch(kind) → summarize → check ─continue→ plan (loop_restart)
                                          └─done | stuck→ exit
```

- **plan**: a tool-free model call. Its packet is the task, `state.edn` and the
  last summary. Its output, written to `turns/<n>/next.edn` by a small tool node,
  is one sub-task: `{:kind :investigate|:code :goal :scope [file:line spans]
  :answer-shape}`.
- **dispatch, `:investigate`**: a fresh agent session with read-only tools
  (`read_file`, `grep`, `glob`, `read_handle`). It answers the sub-task in
  `turns/<n>/result.md`. `shell` is excluded because it can write.
- **dispatch, `:code`**: attractor's coding agent with its full toolset
  (`edit_file`, `apply_patch`, `shell`). It is the only node that changes code.
  Its sub-task names the files and the change. The caller's allowlist guard runs
  after it, and the turn's diff is saved as `turns/<n>/diff.patch`.
- **summarize**: a tool-free model call. It reads `state.edn`, `next.edn` and
  `result.md` and returns a new `state.edn`, written by a tool node.
- **check**: a let-go tool node. Its verdict is mechanical and is written to
  `turns/<n>/check.edn`.

No model writes source except through the `:code` dispatch.

## State document

`state.edn` is the only state carried between turns. Every key is capped by
entry count and characters per entry, so the plan packet stays bounded.

```clojure
{:goal      "..."      ; copied from the task; never rewritten
 :facts     [{:id "F7" :text "..." :evidence "turns/3/result.md"}]
 :decisions [{:id "D2" :text "..." :because ["F7"]}]
 :changes   [{:turn 5 :files ["..."] :summary "..." :diff "turns/5/diff.patch"}]
 :open      ["..."]
 :done      ["T1: ..."]
 :next-hint "..."
 :done-claim false
 :turn      4}
```

- Every fact cites the file it came from, so a later turn can reread the source
  instead of trusting a paraphrase.
- The summarizer adds or revises entries and must merge or drop entries to stay
  within caps. It cannot change `:goal`.
- Default caps: 40 facts, 20 decisions, 20 changes, 10 open questions, 400
  characters per entry.

## Check rules

- **done**: `:done-claim` is true and the caller's done-check command exits 0. A
  model claim alone never ends the loop.
- **stuck**: no new `:facts`, `:decisions` or `:changes` IDs for `stall-turns`
  turns (default 3), or `max-turns` reached (default 12).
- **invalid**: the new `state.edn` fails the schema or the caps. The previous
  state is restored and the turn is retried once; a second invalid result counts
  as stuck.
- Otherwise **continue**.

## Turn files

```
state.edn                   current state
turns/<n>/state.before.edn  state the turn started from
turns/<n>/next.edn          plan's sub-task
turns/<n>/result.md         dispatch answer
turns/<n>/diff.patch        :code turns only
turns/<n>/transcript.jsonl  every event of the dispatch session
turns/<n>/check.edn         check verdict
```

## General agent changes

These apply to every agent session, inside the fragment or not.

1. **Transcripts.** A `:transcript_path` session option attaches an `:on_event`
   writer that appends each session event to a JSONL file. The `:tool_call_end`
   event already carries the untruncated tool output (`agent.lg`
   `execute-single-tool`), so the transcript holds full tool results. The
   codergen handler sets the path to `<stage-dir>/transcript.jsonl` for every
   agent stage; the stage directory reaches the session through
   `:tool_hook_context`.
2. **Usage event.** After each model call, emit `:usage` with `:input_tokens`
   and `:output_tokens`. Today usage is stored only on the assistant turn.
3. **Pre-send backstop.** Before each request, estimate its size from history
   characters, calibrated by the last `:usage` `:input_tokens`, and add
   `:context_reserve_tokens` (default 8192). If that exceeds the known window,
   fail with a `:context-length` error before calling the provider. No
   compaction: the dispatch turn fails, and `check` sees a failed turn.
4. **Per-node tool allowlist.** Attractor's own agent nodes cannot restrict
   tools today (`--tools` exists only for the external `claude` worker). A
   `--tools` node attribute (comma list) removes every other tool from the
   session's registry at creation. A call to a removed tool is a tool error.
5. **`read_handle(path, offset, limit)`.** Pages through a file under the
   current run's logs root. Registered like the subagent tools.

## Configuration

`session_options_fn` for agent nodes reads these node attributes, which a
`model_stylesheet` class can set. The integer parser moves out of
`task_review_bindings.lg` into a shared place.

| Attribute | Session option | Default |
|---|---|---|
| `--context-window` | `:context_window_size` (existing) | discovered |
| `--context-reserve-tokens` | `:context_reserve_tokens` | 8192 |
| `--tools` | tool allowlist | all |

The fragment is a let-go fn following the skeleton's fragment contract:

```clojure
(dispatch-loop/fragment
  {:task       "attractor_runs/research-loop/task.md"
   :state-dir  "attractor_runs/research-loop/state/loop"
   :done-check "test -s attractor_runs/research-loop/state/proposal.md"
   :caps       {:facts 40 :decisions 20 :changes 20 :open 10 :chars-per-entry 400}
   :max-turns 12 :stall-turns 3
   :classes    {:plan "planner" :investigate "reader" :code "maker" :summarize "planner"}})
;; => {:nodes :edges :entry :exits {:success :fail}}
```

It also emits a standalone `dispatch-loop.dot`, usable as a `subpipeline` node
before the skeleton generator exists.

## First use

In the let-go research loop, `propose` becomes a dispatch loop with investigate
turns, done when `proposal.md` is written. `attempt` becomes a dispatch loop
with investigate and code turns, done when the guard and build pass. The rest of
`research-loop.dot` is unchanged.

## Tests

Offline, scripted through `:complete_fn` or the mock adapter:

1. A scripted three-turn loop writes the turn files, evolves `state.edn`, and
   ends `done` when the done-check passes.
2. Three turns with no new IDs end `stuck`.
3. A `state.edn` over caps or failing the schema is `invalid`; the previous
   state is restored and the turn retried once.
4. An investigate session has no write tools; calling `edit_file` is a tool
   error.
5. A code turn writes `diff.patch` and records the change in `:changes`.
6. `transcript.jsonl` holds the untruncated tool output and `:usage` events in
   order.
7. With a tiny window and large history, the backstop raises `:context-length`
   and the mock records zero provider calls.
8. Node attributes from a stylesheet reach the session options.
9. `pipeline/prepare` accepts the fragment's emitted DOT, and the standalone DOT
   runs end to end on the mock provider.

Live, opt-in (skipped without the server): the research loop's new `propose`
runs on `qwen3.8-27b`, and its transcripts show every request below the window.

## Out of scope

- The in-session `:context_strategy :dispatch` (stage 2).
- The optimization-loop skeleton generator.
- Context-handle tools beyond `read_handle`, such as `ctx_grep` or `ctx_chunks`.
- Summarizing tool results or compacting history inside a session.

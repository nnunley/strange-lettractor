# Agent context foundations

Status: split on 2026-10-02 from the dispatch-loop design
(`2026-10-01-dispatch-loop-context-design.md`), which depends on it; revised
the same day after a pushback review. Implementation planning has not started.
It has no prerequisites.

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

Every agent stage leaves a full, redacted transcript. A request that would
exceed the window fails before it is sent, with the numbers. A node can restrict
its agent to named tools, an agent can page through large raw files on disk, and
changes to a tree are recorded as small refs instead of diff text.

Each piece below is useful on its own and ships as its own PR. The dispatch
loop uses all of them.

## Per node run, not per session

Nodes with `fidelity="full"` on one thread share a session
(`make-agent-codergen-backend`, `agent.lg`): `make-session` runs only for the
first node, so options fixed at creation would apply to every later node on
the thread. Every setting below is therefore resolved for each node run, from
the node being run, not at session creation. The node's stage directory already
reaches the session per turn, through `:tool_hook_context` at admission.

## 1. Transcripts

The session attaches one transcript writer through `:on_event`. Each event is
appended, one JSON object per line, to `<stage-dir>/transcript.jsonl` for the
stage directory of the turn in flight, so each node on a shared thread gets its
own file.

- The `:tool_call_end` event already carries the untruncated tool output
  (`agent.lg` `execute-single-tool`, before `truncate-tool-output`), so the
  transcript holds full tool results without capturing anything twice.
- Every event passes through `providers/redact` before it is written: configured
  API keys, credential-header values and Bearer/Token values become
  `<credential>`.
- Transcript and handle files are created with mode 0600.
- On the first write in a run, if the logs root is not ignored by the
  repository's VCS (`git check-ignore`, or the jj equivalent), the session emits
  one `:warning` naming the path.
- A write failure emits a `:warning` event and stops the writer; it never fails
  the stage.

Redaction is defense in depth. It covers secrets attractor knows about; it does
not stop an agent reading a key file through `shell` or `read_file`. Removing
secrets from the agent's reach is the subject of the secrets design
(`2026-10-02-secret-values-and-connections-design.md`).

## 2. Usage event

After each model call, emit `:usage` with `:input_tokens`, `:output_tokens`,
and the cache read/write counts when the provider reports them. Today usage is
stored only on the assistant turn, where nothing but `sum-usage-tokens` reads
it.

## 3. Pre-send backstop

Before each request, compute its size:

- Start from the last provider-reported input tokens (cache reads and writes
  included). With no report yet, start from zero and count the whole history.
- Count the history added since that report with the provider's token counter:
  llama.cpp's `/tokenize` (a llama.cpp server is recognised the way
  `context_discovery.lg` already recognises it), Anthropic's token-counting
  endpoint, Gemini's `countTokens`.
- When the provider has no counter, or the count call fails, estimate that part
  as characters/3.

Add `--reserve-tokens` (default 8192). If the total exceeds the known window,
fail with a `:context-length` error before calling the provider; the error names
the count, the reserve, the window and whether the count was exact. Otherwise
clamp the request's output-token limit to the smaller of `--max-output-tokens`
and the remaining headroom. When the window is unknown, the backstop does
nothing.

A provider's own context-length rejection (for example llama.cpp's HTTP 400
`exceed_context_size_error`) becomes the same structured `:context-length`
failure, so a miscount still fails the same way.

There is no compaction: the request fails early instead of failing at the
provider.

## 4. Per-node tool allowlist

Attractor's own agent nodes cannot restrict their tools today; `--tools` exists
only for the external `claude` worker. A `--tools` node attribute (comma list)
limits the node's agent to those tools, per turn: only their definitions are
sent with the node's requests, and a call to any other tool is a tool error.
An unknown name in the list fails the node at start.

## 5. `read_handle`

`read_handle(path, offset, limit)` pages through a file under the current run's
logs root, by lines. A path outside the logs root is a tool error. It is
registered like the subagent tools (`agent.lg` `register-subagent-tools!`).

## 6. Versioning adapter

A new namespace, `attractor.versioning`, records the state of a tree without
writing to the repository:

```clojure
(defprotocol IVersioning
  (snapshot! [v label])          ; => ref
  (changed-files [v from to])    ; => [paths]
  (diff [v from to opts]))       ; => diff text; opts {:paths [...] :stat? bool}
```

A ref has one shape:

```clojure
{:repo  {:protocol :git :root "/path/to/repo"}   ; :git, :jj or :dir
 :base  "a1b2c3d"                                ; a commit the protocol resolves; nil for :dir
 :patch "turns/5/after.patch"}                   ; uncommitted changes, untracked files
                                                 ; included; nil when clean
```

- `snapshot!` records the current base (git `HEAD`, the jj working-copy
  parent) and writes the uncommitted changes as a patch file under the logs
  root. It never commits, stashes, moves refs or touches the index.
- `:dir` covers a tree with no VCS: its base is an initial copy recorded on the
  first snapshot, and its patch is taken against that copy.
- `diff` and `changed-files` take any two refs. With a shared base they answer
  from the two patch files; otherwise the adapter rebuilds both trees, base plus
  patch, in a temporary directory and compares them.
- `:repo` travels with every ref, so a ref read later says how to resolve
  itself. The protocol is detected from the root (`.jj`, then `.git`, else
  `:dir`).
- The adapter instance is passed as a session or pipeline option; it is never
  taken from the agent's environment.
- Transcripts record a `:snapshot` event `{:label :ref}`; diff text never enters
  a transcript.

Two ways to read a diff, both calling `diff`:

- `diff_refs(from, to, paths?)`, a read-only agent tool, paged and size-limited
  like `read_handle`.
- `attractor diff <from> <to> [paths...]` on the CLI, for people.

Committing, resetting and restoring stay the caller's job.

## Configuration

`session_options_fn` for agent nodes reads these node attributes, which a
`model_stylesheet` class can set. They are the names reviewer and planner nodes
already read (`task_review_bindings.lg`); the integer parser moves into a
shared place so every LLM node reads them the same way.

| Attribute | Meaning | Default |
|---|---|---|
| `--context-window` | window size; overrides discovery (`:context_window_size`) | discovered |
| `--reserve-tokens` | tokens the backstop keeps free | 8192 |
| `--max-output-tokens` | cap on the request's output-token limit | provider default |
| `--tools` | tool allowlist | all |

Transcripts need no attribute.

## Tests

Offline, scripted through `:complete_fn` or the mock adapter:

1. `transcript.jsonl` holds the user input, the tool call, the untruncated tool
   output, the assistant turn and `:usage` events, in order.
2. Two nodes on one full-fidelity thread write separate transcripts, and a
   second node's `--tools` and `--reserve-tokens` apply to its own turns.
3. A configured API key planted in tool output appears in the transcript as
   `<credential>`; the file mode is 0600; an unignored logs root warns once.
4. A transcript write failure warns and the stage completes.
5. With a tiny window and large history, the backstop raises `:context-length`
   and the mock records zero provider calls.
6. The count uses the provider counter for new history and characters/3 when
   the counter is missing or fails; the output-token limit is clamped to the
   smaller of `--max-output-tokens` and the headroom.
7. A provider context-length rejection becomes the same `:context-length`
   failure.
8. An unknown window disables the backstop.
9. A `--tools` node sends only the named definitions; calling another tool is a
   tool error; an unknown name fails at start.
10. `read_handle` pages by offset and limit, and refuses a path outside the logs
    root.
11. Versioning on a git repository, a jj repository and a plain directory:
    `snapshot!` leaves the repository's refs, index and stash unchanged;
    `changed-files` and `diff` between two snapshots match the edits made
    between them, with and without a shared base; `diff_refs` and
    `attractor diff` return the same text.
12. Node attributes from a stylesheet reach the session options.

Live, opt-in (skipped without the server): rerun the research loop's `propose`
on `qwen3.8-27b` and check that its transcript shows which reads grew the
context and that the backstop, counting with `/tokenize`, fails it before the
provider does.

## Out of scope

- The dispatch loop (its own spec).
- Summarizing tool results or compacting history inside a session.
- Token budgets and turn limits per node (the stylesheet constraints design).
- A secret value type and authenticated connections (the secrets design).
- Embeddings for semantic search over handles or facts.

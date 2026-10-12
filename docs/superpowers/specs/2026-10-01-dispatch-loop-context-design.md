# Dispatch loop: bounded context for long agent stages

Status: design approved in conversation on 2026-10-01; split and revised on
2026-10-02 after a pushback review. Implementation planning has not started. Stage 1 (workflow
fragment) is specified here; stage 2 (an in-session strategy) gets its own short
spec later.

## Prerequisites

- **Agent context foundations** (`2026-10-02-agent-context-foundations-design.md`):
  transcripts, the usage event, the pre-send backstop, the per-node tool
  allowlist, `read_handle` and the versioning adapter.
- **Stylesheet constraints** (`2026-09-19-stylesheet-constraints-design.md`):
  every budget in the loop is a constraint. Each dispatch class is bounded with
  `tokens` and `turns` (for example `.reader { tokens <= 64000; turns <= 30; }`),
  and the loop as a whole is bounded by the enclosing token budget. This design
  adds no limits of its own.

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

Prior art: evener (`~/development/evener/docs/design/context.md`) compacts one
long-lived session under pressure: a deterministic checkpoint at 80% of the
window, then a model summary at 95%, plus a forced step that lists IDs and
numbers to keep verbatim, added after its evals showed facts eroding across
summaries. It avoids editing the middle of history because that invalidates
provider prefix caches. This design borrows its verbatim-fact prompt, its token
estimate, its output clamp and its recall eval.

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
  :files [paths] :answer-shape}`. The writer takes the first EDN map in the
  response, so a code fence or surrounding prose is tolerated, and checks it:
  `:kind` is `:investigate` or `:code`, `:goal` is not blank, and a `:code`
  sub-task names at least one file, all inside the caller's allowlist. Scope
  spans naming missing files are kept and flagged in `check.edn`, since a turn
  may create a file. A failed check retries once on `--fallback-model`; a second
  failure makes the turn invalid and nothing is dispatched.
- **dispatch, `:investigate`**: a fresh agent session with read-only tools
  (`read_file`, `grep`, `glob`, `read_handle`). It answers the sub-task in
  `turns/<n>/result.md`. `shell` is excluded because it can write.
- **dispatch, `:code`**: attractor's coding agent with its full toolset
  (`edit_file`, `apply_patch`, `shell`). It is the only node that changes code.
  Its sub-task names the files and the change. The fragment calls the
  versioning adapter's `snapshot!` before and after it, and the caller's
  allowlist guard runs after it. The two refs and the changed files go into
  `:changes`; the diff text stays retrievable through `diff_refs` and never
  enters state or transcripts.
- **summarize**: a tool-free model call. It reads `state.edn`, `next.edn` and
  the full `result.md` and returns a new `state.edn`, written by a tool node.
  Its prompt asks explicitly for opaque IDs, hashes, exact numbers and paths
  that came from tool output, and those go into `:facts` verbatim. It also says
  never to record a credential: a fact may cite the file a credential appeared
  in, never the value. Its output passes through `providers/redact` before it is
  written. If the call fails or returns unparseable output, it is retried once
  on `--fallback-model`; a second failure makes the turn invalid.
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
 :changes   [{:turn 5 :from {ref} :to {ref} :files ["..."] :summary "..."}]
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
- `state.edn` never holds a secret. `check` rejects one that contains a
  configured secret or a credential-shaped value (a Bearer/Token header value,
  a known API-key prefix).
- A ref in `:changes` is the versioning adapter's ref: `{:repo :base :patch}`.

## Check rules

- **done**: `:done-claim` is true and the caller's done-check command exits 0. A
  model claim alone never ends the loop.
- **stuck**: no new `:facts`, `:decisions` or `:changes` IDs for `stall-turns`
  consecutive turns (default 3). This is a progress rule, not a resource limit:
  resource limits come from constraints. Constraint `turns` counts agent turns
  within one node run, so it cannot count loop iterations; a loop that keeps
  producing new IDs ends when the enclosing token budget is exhausted.
- **stuck, budget**: a dispatch, plan or summarize node failed with
  `:constraint_violated` or a budget-exhausted reason. The loop exits with
  `stop_reason: budget`; `state.edn` stays at its last valid version, and the
  interrupted turn's files, refs and transcript stay on disk for whoever
  resumes.
- **invalid**: the new `state.edn` fails the schema, the caps or the secret
  rule. The previous state is restored and the turn is retried once; a second
  invalid result counts as stuck.
- Otherwise **continue**.

## Turn files

```
state.edn                   current state
turns/<n>/state.before.edn  state the turn started from
turns/<n>/next.edn          plan's sub-task
turns/<n>/result.md         dispatch answer
turns/<n>/before.patch      :code turns: the snapshot before the dispatch
turns/<n>/after.patch       :code turns: the snapshot after it
turns/<n>/transcript.jsonl  every event of the dispatch session
turns/<n>/check.edn         check verdict
```

## Uses of the foundations

- Each dispatch session writes `turns/<n>/transcript.jsonl` (foundations §1).
- A dispatch whose request would exceed its window fails before sending
  (foundations §3); `check` sees a failed turn.
- `investigate` classes set `--tools: read_file,grep,glob,read_handle`
  (foundations §4).
- `plan` and later turns reread evidence through `read_handle` (foundations §5).
- `:code` turns are recorded as versioning refs, and any turn can read a diff
  through `diff_refs` (foundations §6).

## Configuration

One new node attribute, read by plan and summarize nodes:

| Attribute | Meaning | Default |
|---|---|---|
| `--fallback-model` | model for the one retry after a malformed response | none |

The fragment takes the versioning adapter as an option (`:versioning`); when
absent it builds one for the working directory.

The fragment is a let-go fn following the skeleton's fragment contract:

```clojure
(dispatch-loop/fragment
  {:task       "attractor_runs/research-loop/task.md"
   :state-dir  "attractor_runs/research-loop/state/loop"
   :done-check "test -s attractor_runs/research-loop/state/proposal.md"
   :caps       {:facts 40 :decisions 20 :changes 20 :open 10 :chars-per-entry 400}
   :stall-turns 3
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
4. The emitted investigate nodes carry the read-only `--tools` list.
5. A code turn records before and after refs and the changed files in
   `:changes`; the repository's refs, index and stash are unchanged; no diff
   text appears in `state.edn` or the transcript.
6. A failed dispatch (for example a backstop `:context-length`) is recorded in
   `check.edn` and does not end the loop by itself.
7. `pipeline/prepare` accepts the fragment's emitted DOT, and the standalone DOT
   runs end to end on the mock provider.
8. A summarizer failure retries once on the fallback model; a second failure
   makes the turn invalid and restores the previous state.
9. With an enclosing `tokens` constraint, a loop that keeps producing new IDs
   exits `stuck` with `stop_reason: budget` when the budget is exhausted, and
   `state.edn` is the last valid version.
10. A plan response wrapped in a code fence is accepted; one with an unknown
    `:kind`, or a `:code` sub-task naming a file outside the allowlist, retries
    on the fallback model and then makes the turn invalid without dispatching.
11. A summarizer output containing a configured secret is written redacted, and
    a `state.edn` holding a credential-shaped value is rejected as invalid.

Live, opt-in (skipped without the server):

- The research loop's new `propose` runs on `qwen3.8-27b`, and its transcripts
  show every request below the window.
- Recall eval: a scripted task plants exact facts (an ID, a hash, a number, a
  path) in early turns' tool output; after 10 turns, `state.edn` still holds
  each one verbatim. This measures summary erosion, following the method in
  evener's compaction retention evals.

## Out of scope

- The in-session `:context_strategy :dispatch` (stage 2).
- The optimization-loop skeleton generator.
- Context-handle tools beyond `read_handle`, such as `ctx_grep` or `ctx_chunks`.
- Summarizing tool results or compacting history inside a session.

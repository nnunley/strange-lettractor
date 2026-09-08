# Console milestone: driving Attractor from its own UI

Goal (user, 2026-09-08): implement enough of the Attractor specification that
the remainder can be finished from a strange-lettractor UI. This document is
the implementation slice of the approved
[console and workers design](../../console-workers-design.md); it changes no
ownership decision there. The console remains a client of the hub.

## What "enough" means for this milestone

A user in the console can, against the in-process hub:

1. Message an agent session (unprefixed text) and watch identified streamed
   events from the real agent loop (Qwen through llama.cpp when available, a
   deterministic fixture provider in tests).
2. Evaluate let-go (`: form`, `:{ ... :}`) in a persistent hub-owned console
   namespace with `*session*`/`*run*` bound at submission and `hub` helpers
   available, one eval at a time, errors rendered, nothing implicit.
3. Launch a DOT workflow (`/run file.dot [--auto-approve]`), see its lifecycle
   events, and cancel it (`/cancel`) without terminating the hub.
4. Dispatch an owned external coding-agent worker (`/claude <prompt>` with
   `--cwd`, `--tools`, `--permission-mode`, `--model` options) and watch its
   identified protocol/text events; failure, cancel and exit are visible.
5. Switch focus between sessions, runs and workers (`/focus`), list them
   (`/agents`), quit (`/quit`, EOF) with the terminal restored and hub-owned
   work left running or explicitly cancelled.
6. Use the same dispatcher from a line frontend (non-TTY, transcript-testable)
   and from a tiny-tui full-screen frontend.

Out of scope here: separate-process RPC/nREPL transport, reconnect/replay
across processes, Codex app-server worker, multiple concurrent evals.

## Components

- `attractor.hub` gains operations, each emitting identified events into the
  existing bounded log with a distinct `:source`:
  - `:eval/submit {:code :session_id :run_id}` → `{:value|:error :printed}`;
    `:source :eval`. One evaluator, serialized; a busy evaluator rejects with
    `:busy`. Namespace `attractor.console.user` persists for the hub lifetime.
  - `:workflow/run {:dot_source :source_path :logs_root :auto_approve}` →
    `{:run_id :completion}`; `:workflow/cancel {:run_id}`; `:workflow/list`.
    Runs are hub-owned futures under the supervisor's child scope; events are
    the pipeline `:on-event` maps, `:source :workflow`.
  - `:worker/run {:kind :claude :prompt :working_dir :model :tools
    :permission_mode :timeout_ms}` → `{:worker_id :completion}`;
    `:worker/cancel {:worker_id}`; `:worker/list`. Events are the connector's
    records, `:source :worker`.
  Cancellation for workflows and workers uses cooperative `cancelled?` flags
  plus scope cancellation of the owned future; completion promises resolve
  with `{:value}` or `{:error {:category ...}}` and are published under the
  event lock like agent turns.
- `attractor.console.session`: the dispatcher shared by both frontends. Holds
  client attachment, focus, and the input reducer state. `handle!` takes a
  reducer event, returns `{:lines [...]}` to render and performs hub requests.
  `drain!` returns newly readable events as rendered lines. Pure rendering
  functions map hub envelopes to prefixed lines (`[agent s1]`, `[eval]`,
  `[run r1]`, `[claude w1]`).
- `attractor.console.line`: stdin/stdout frontend. One reader future owns
  stdin; a renderer loop drains hub events between lines. `attractor console`
  in the CLI starts a hub with the configured model profile and runs it.
- `attractor.console.tui`: tiny-tui frontend. An app-owned loop merges key
  messages with hub event polls (the stock `run` loop only waits for keys) and
  routes Ctrl-C by state: discard draft, cancel focused work, or quit when
  idle. Headless tests use tiny-tui's `:screen false`/`:read-key-fn`/
  `:render-fn` seams. Dependency pinned in `lgx.edn` at `v0.1.3`.

## Evidence

- Hub operation tests with the fixture provider, a mock DOT workflow and a
  let-go fake worker command: identified events, busy/cancel/error paths,
  cancellation leaving the hub alive.
- Console transcript test: scripted lines through `session/handle!` and
  `drain!` cover every input route, focus capture at submission, eval error
  then success, workflow run and cancel, worker run.
- tiny-tui headless test: same script through the TUI loop with scripted keys
  and a captured render; Ctrl-C routing by state.
- Native: `attractor console` under a PTY with the fixture provider: prompt,
  a message, an eval, `/quit`, terminal restored. Live Qwen and external
  worker trials are recorded separately and never required for the
  deterministic gates.

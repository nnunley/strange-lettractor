# Hub usage

The hub owns native sessions, workflow runs, external-agent jobs, events,
human questions and cancellation. CLI commands use the same request contract;
tools execute in their owning sessions.

## Live console activity

Both interactive consoles show one activity row above the editable prompt:
`Reading files · 3 active · 12 done`, for example. The ordinary console uses
inline tiny-tui rendering and preserves scrollback; `--tui` uses a fixed row.
Assistant messages, errors and final results remain in the transcript. Pipes
retain plain output. Counts describe tool calls observed since acquiring focus,
not a percentage of the task or a count of agents. Missing events invalidate the
previous counts. Activity summaries use structured events, without model calls.

Ctrl-C clears a nonempty draft first, cancels focused work when busy with no
draft, and exits when idle. Ctrl-D exits on an empty editor; otherwise it deletes
at the cursor. Activity updates preserve the draft. The full-screen transcript
retains up to 2,000 lines; the inline console leaves transcript history in terminal
scrollback. Unicode clipping currently reserves two cells per non-ASCII character.

## Typed presentations: design direction

Typed selection and command arguments are the next increment; the activity row
above does not yet provide these interactions.

[Ciccarelli's 1984 thesis](https://dspace.mit.edu/entities/publication/6540a5e7-e056-4542-a3d9-0dd7646ea004)
separates application state, presentation state, presentation updates and recognition
of user actions. Its sections 3.1–3.2 also distinguish proposed state and commands
from executed changes. For this console, the hub remains authoritative; selection,
expansion and command drafts belong to the client.

[A Guided Tour of CLIM](https://mcclim.common-lisp.dev/static/documents/guided-tour.pdf)
(original 1991, updated 2006), sections 6–6.1, explains reusable typed output and
context-dependent input. The [CLIM translator contract](https://www.lispworks.com/documentation/lw81/clim/clim-ch8-1.htm)
connects a selected object to an accepted argument or command. Our implementation
should support both selecting an object and choosing an action, and starting a
command and selecting a compatible argument, through the same host operations.

BTRON supplies a complementary identity model: [real objects and virtual references](https://www.chokanji.com/ckv/qr/object.html),
including [embedded expanded views](https://download.personal-media.co.jp/ckv/manual/01-03-19.html).
This is a parallel influence, not an established historical descendant of the
thesis. For the harness, several views should reference one tool call, agent or
artifact. Expansion reads its recorded result; it never reruns the operation.

Start with bounded tool-call and agent references, keyboard selection, inspection
and a supported command accepting an agent reference. Preserve draft input and
selection identity as events arrive. Revalidate live actions at dispatch; clearly
mark expired references. A displayed path becomes actionable only when its origin
and working directory are known. Keep proposed commands distinct from execution.
Tiny-tui supplies terminal rendering and input; shared typed values and command
semantics must remain independent of the frontend.

## Run a shared host

```sh
bin/attractor hub --mock --port 4555
```

From other terminals:

```sh
bin/attractor console --connect 4555
bin/attractor console --connect 4555 --tui
bin/attractor serve --connect 4555 --port 127.0.0.1:7070
```

The host accepts model/backend options; `--mock` needs no live model. Attaching
clients use the host's configuration. `/quit` detaches the console and preserves
hub-owned work. `/answer <key or text>` answers a pending human gate, preferring
the focused workflow. `--auto-approve` is optional.

The `hub` and standalone `console` commands enable a durable continual harness
for native sessions. Use `--harness PATH` to reopen an explicit ledger,
`--harness-interval N` to change automatic refinement cadence, `--no-auto-refine`
for manual refinement, or `--no-harness` to disable it. Set these on the host,
not an attached client. See [interactive harness usage](../examples/continual-harness/README.md).

Console input requests queuing: busy ordinary input steers at a safe boundary,
and `/followup TEXT` waits behind the current work. Queued acknowledgments identify
the same aggregate turn; its result settles after accepted inputs drain. Direct
`:session/submit` calls retain busy rejection unless `:queue true` is supplied.
`/context` inspects the selected session's context estimate; `/compact` requests a
checkpoint before its next model call. Both use host operations, so they also work
from attached clients. See [context capacity](context-capacity.md) for admission
and overflow-recovery behavior.

`/harness` and `/refine` operate on the selected native session through the hub,
including when the console is attached over nREPL.

Framework repair is optional and configured on the host with `--repair-config
PATH` (`hub`, standalone `console`, or standalone `serve`). It uses inference and
coding tools, not model training. The stronger triage/review model is explicit;
it does not silently reuse the working agent's model. Example trusted EDN:

```clojure
{:repository "/Users/ndn/development/attractor"
 :triage_model "openrouter/meta/muse-spark-1.3-contributor"
 :test_command "LGX_LG=/Users/ndn/development/let-go/bin/lg lgx suite"
 :build_command "LGX_LG=/Users/ndn/development/let-go/bin/lg lgx rebuild"
 :timeout_ms 1800000
 :max_incidents 32
 :max_model_calls 32
 :max_turns 12
 :max_total_tokens 60000}
```

The checked-in [repair.edn](../repair.edn) uses this configuration: Muse for
triage, coding and independent review. The normal working session can still use
local Qwen. OpenRouter credentials are
resolved through the existing provider registry. [Muse Contributor](https://openrouter.ai/meta/muse-spark-1.3-contributor)
prompts and outputs may be used to improve Meta’s products. Adjust the absolute
repository/runtime paths for another checkout. Omit `:coding_model`
to use the triage model for coding too. Commands run in the repair checkout;
the test command must discover newly added files under `test/`. Increase the time
budget if the repository's baseline suite, regression run, fixed suite and build
need more than thirty minutes. Limits also bound model calls and generated output;
missing provider usage is charged conservatively from serialized request size.
`:max_turns` is the cumulative worker call limit, including independent review.

```sh
bin/attractor console --llm --model llamacpp/qwen3.8 --repair-config repair.edn
# Or expose the same host to HTTP and console clients:
bin/attractor serve --llm --model llamacpp/qwen3.8 --repair-config repair.edn
```

`serve` prints the HTTP API URL, by default
`http://localhost:7070/pipelines`. This is the pipeline API, not a browser UI.
The separately printed nREPL port is used by `console --connect`.

Native session and child-tool exceptions carry bounded history, arguments,
working directory and delegation context into triage. These snapshots are sent
to the configured triage provider. Tool-use, environment and provider diagnoses
produce advice; procedural diagnoses can request existing harness refinement.
Only a framework diagnosis with evidence and reproduction steps starts a coder.
A missing path alone is not grounds for changing `read_file`.

The host snapshots the configured **framework repository** revision at startup,
independently of the working agent's task directory. Commit source changes and
restart the host after changing framework revisions. Repairs require unchanged,
clean tracked framework source and an ignored `attractor_runs/` directory. They
use branches and worktrees under `attractor_runs/repairs/`, leaving the main
checkout intact. Coding tools permit file reads and guarded edits within the
worktree, with no shell/subagents; verification commands come only from the
trusted host configuration. Those commands run with the host's permissions;
this is not an OS sandbox.

The host verifies a passing baseline, a new test that fails before source edits,
unchanged regression tests that pass after the fix, a successful build, and
independent strong-model review before committing. Failed attempts are retained
for inspection and never automatically retried. There is no automatic replay of
the operation that failed.

Both console modes and attached consoles support:

- `/repair` — list incidents and status.
- `/repair ID` — inspect diagnosis, failures, worktree and prepared commit.
- `/repair cancel ID` — cancel queued or active work.
- `/repair activate ID` — explicitly fast-forward a clean, unchanged checkout to
  a verified commit and rebuild. The host must be idle. **Restart after successful
  activation**; this command does not replace the running process. A failed build
  is reported separately; the source checkout may already have advanced.

A compact `attractor_runs/repairs/index.edn` ledger retains bounded incident
snapshots and verification excerpts across restarts. Interrupted work is marked
interrupted rather than replayed. Identical failures at the same source revision
are deduplicated. The incident limit applies to retained ledger entries; when
full, new incidents are dropped and counted in status. It is diagnostic state,
not part of the continual-harness ledger. To reset it, stop the host first,
archive/remove that index and remove unneeded worktrees with `git worktree remove
PATH`; keep prepared Git commits you want to retain. A repository permits one
repair supervisor at a time. Normal shutdown releases `supervisor.lock`; after a
crash, check that its owner has stopped before removing the empty lock directory.
Ledger write failure stops admission and is reported by `/repair`.

Stop the host explicitly:

```sh
bin/attractor hub --stop 4555
```

Stop acknowledges the request before the host closes connections and shuts down
its work. `hub --port 0 --port-file PATH` chooses an available port and publishes
it in a new file; normal shutdown removes the host's own file.

## Ownership by command

| Command | Hub ownership |
|---|---|
| `run`, `resume`, `agent` | Embeds and owns a hub for the command. |
| `console` | Embeds a hub unless `--connect PORT` is supplied. |
| `hub` | Owns a persistent hub and loopback nREPL listener. |
| `serve` | Owns a hub and nREPL listener, with HTTP routed through nREPL. Use `--nrepl-port PORT` to select that listener's port. |
| `serve --connect PORT` | Attaches HTTP to an existing hub; stopping the HTTP process leaves the host's work alive. |

`--connect` names a loopback nREPL port, not a URL. HTTP's `--port` is a listen
address. The nREPL protocol uses bencode envelopes containing EDN data; it also
provides explicit evaluation in the persistent console namespace. Treat it as
trusted local access, not an authenticated multi-user service.

## Current limits

- Connections do not reconnect automatically. Lost mutation replies have an
  unknown outcome and must not be retried blindly.
- Session result lookup retains only the latest turn. Event cursors support
  replay within retained history, not durable recovery across host restarts.
- Request waits are bounded, but client lock acquisition and socket writes do
  not have independent deadlines; payload checks follow frame decoding.
- Signal-triggered graceful shutdown and an owned HTTP shutdown API remain
  unestablished. Explicit host stop is the supported lifecycle path.
- This is an Attractor nREPL extension, not full editor nREPL middleware support.

Implementation: `src/attractor/cli.lg`, `nrepl_client.lg`, `nrepl_server.lg`,
`nrepl_hub.lg`, and `hub_http.lg`. Contract tests cover console attachment,
question answering and shared HTTP controls. Native/compiled probes live in
`test/probes/nrepl_hub_check.lg` and `test/probes/hub_host_check.lg`.

The [archived nREPL notes](_archive/nrepl-hub.md) retain protocol details and
dated verification; their old separate-HTTP-registry and patched-runtime
statements are superseded by the current implementation and stock let-go 1.13.0.

## Proposed browser session workbench and repair supervision

This section is a design proposal, not implemented behavior. `serve` currently
exposes the pipeline API; it does not serve an interactive session REPL.

The inspected Evener checkout provides useful reference boundaries:
`cmd/evener-hub/internal/hubcore/config.go` defines a spawner for session `serve`
subprocesses; `internal/appsource/local_daemon.go` supplies read/start/steer
operations, and `app_subagent_preview.go` derives bounded child previews from
thread items. Its browser session pane is a client of those operations.
The local let-go `examples/browser-inspector` demonstrates a browser evaluation
workbench, but only for one embedded default session. It is not itself a remote
agent-session manager; the intended Andrey example still needs identification.

Recommended shape:

- A stable hub owns browser/terminal attachments, session identities and parent/
  child relationships, event cursors, durable conversation checkpoints, continual
  harness ledgers, and repair supervision. Clients select typed sessions, agents,
  tool calls and files to inspect or act on through the same hub operations.
- A browser workbench attaches to existing sessions, streams transcripts and
  current activity, sends steering or queued follow-ups, drills into subagents,
  answers questions, and inspects refinement/repair activity. It reconnects using
  a snapshot plus event cursor, recovering explicitly from cursor expiry. Lisp
  evaluation is a distinct explicit mode, as in the terminal console. Exposing
  these controls requires loopback defaults and same-origin/authenticated browser
  requests, not the pipeline API's existing wildcard CORS behavior.
- A supervised worker process owns the agent/tool loop for a session and its
  subagent tree. The hub tracks worker generations, rejects stale replies, and
  remains available if a worker crashes or fails to load an updated revision.
  Conversation recovery must checkpoint transcript, context projection, queued
  inputs and outstanding operation identities, not only adaptive harness state.
  Interrupted side effects are reported as uncertain rather than replayed.
- Normal triage, repair coding and review use the configured Muse model. A
  bounded emergency advisory stage may invoke the existing Codex or Claude Code
  connectors after normal repair fails or the worker cannot boot. It receives
  incident/reproduction/patch evidence and can propose a remedy; host verification
  and explicit activation still apply. Its failures never recursively escalate.
- Continual improvement covers both adaptive refinement and source repair, with
  one visible incident lifecycle. Successful verified repairs feed a concise
  revision-linked outcome back into harness memory; attempted or unverified fixes
  never become asserted lessons. Source commits and adaptive ledger edits keep
  their existing distinct validation paths.

There are three activation approaches: in-process reload only (simple, but shares
failure state and captured callbacks), replacement workers only (clear recovery,
but requires checkpoint/restore), or a hybrid. Prefer the hybrid: replace workers
for framework/state changes; permit narrowly scoped dynamic reload only after
pausing new work, verifying compatibility, rebinding affected handlers, and
checking health. A local let-go probe confirmed that redefining a var updates a
fresh call while a previously captured function still invokes the old code.

Implementation order: first add hub operations for a session/subagent tree and
bounded transcript snapshots, then the browser client; next add emergency advisor
routing and verified outcomes to continual refinement; finally add worker
checkpoint/restore and generation-aware replacement, with dynamic reload as a
restricted optimization. Acceptance must demonstrate child interaction, browser
reconnection, real worker death during a tool call, no duplicate side effects,
failed-update recovery, and repair of an unbootable worker while the hub remains
usable. The conversational threading work below implements the browser UI. Emergency
escalation, worker subprocesses and reload activation remain future work.

## Conversational threading implementation

The interactive UI uses the existing EDN history shape as its conversation
record. Each root session owns a tree of thread records; a thread identifies its
root and parent, task, model, state, and ordered user/assistant/tool history.
The hub supplies `thread/list`, `thread/read`, `thread/submit`, `thread/cancel`,
and explicit `thread/resume`. Clients select a thread before sending input.
A reconnect reads a complete thread snapshot; the bounded activity event stream
is notification rather than the only copy of the conversation.

Snapshots live under `attractor_runs/conversations/` for CLI-owned hubs, with
one atomically replaced EDN file per root. Embedded hubs opt in with
`:conversation_root`. Persist at meaningful conversation boundaries, not on
streaming token deltas. The agent emits `:tool_results_recorded` after appending
completed tool results and before starting another provider call; this is the
durable tool-turn boundary (`:tool_call_end` occurs before the history append). Restored threads are inspectable archives; no provider
call or tool is replayed on startup. Explicit resume creates a new root session
linked to the archived thread, carrying completed history. Interrupted calls
without results must be refused rather than fabricated or replayed. Host model,
tools and permissions come from current startup configuration.

Implementation sequence:

- [x] Add serializable thread snapshots and atomic EDN archive storage; test
      nested threads, corrupt snapshots and restart inspection.
- [x] Integrate hub thread operations, child input/cancellation and explicit
      history resume; test targeting and interrupted-call refusal.
- [x] Expose thread selection and transcript inspection in both consoles and a
      same-origin browser workbench through the existing HTTP server.
- [x] Verify persisted thread recovery, HTTP boundaries, UI routing and existing
      hub/console behavior, review, and commit the implementation.

This extends the co-learning history representation and existing workflow and
harness artifacts. It does not introduce a database or copy Samizdat code.

### Using conversations

Run `attractor serve` and open the printed Conversation UI URL (by default
`http://127.0.0.1:7070/`). Type and send immediately to create a conversation;
Enter sends and Shift+Enter inserts a newline. Select a root or child in the tree to inspect its
transcript and tool-call presentations. Send a steering message at the next
boundary, or choose a followup after current work. New conversation, Cancel work
and Resume archive operate on the selected thread. The browser workbench accepts
only loopback hosts and peers; use a local SSH tunnel for a remote hub.

Both `console` and `console --tui` support `/threads`, `/thread <id>` and
`/resume <id>`. Thread selection accepts a full ID or an unambiguous short ID.
Subsequent messages and cancellation target that thread. Resume creates a new
root linked to the archive; it does not restart old children or submit pending
inputs automatically. Queued inputs remain visible in the archive for inspection.

Restart from the same working directory to reopen its conversation archives.
Only one hub may own a conversation directory; attach additional clients with
`--connect <nrepl-port>`. A hard process kill can leave
`attractor_runs/conversations/owner.lock`; remove that empty directory only after
confirming the previous owning hub has stopped. Corrupt archives fail startup
rather than being silently discarded. These files contain conversation and tool
contents, so treat them as private working data.

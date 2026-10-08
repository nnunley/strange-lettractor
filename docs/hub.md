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
 :triage_model "provider/strong-model"
 :coding_model "provider/coding-model"
 :test_command "LGX_LG=/Users/ndn/development/let-go/bin/lg lgx suite"
 :build_command "LGX_LG=/Users/ndn/development/let-go/bin/lg lgx rebuild"
 :timeout_ms 600000
 :max_incidents 32
 :max_model_calls 32
 :max_turns 12
 :max_total_tokens 60000}
```

Replace the model names with configured providers/models. Omit `:coding_model`
to use the triage model for coding too. Commands run in the repair checkout;
the test command must discover newly added files under `test/`. Increase the time
budget if the repository's baseline suite, regression run, fixed suite and build
need more than ten minutes. Limits also bound model calls and generated output;
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

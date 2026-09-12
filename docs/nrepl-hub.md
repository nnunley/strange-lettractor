# Native nREPL access to the hub

Run a configured host in one terminal, then attach clients from others:

```sh
bin/attractor hub --mock --port 4555
bin/attractor console --connect 4555
bin/attractor serve --connect 4555 --port 127.0.0.1:7070
bin/attractor hub --stop 4555
```

The host accepts the same model/backend options as workflow commands. Use
`--port 0 --port-file PATH` for an OS-assigned port; the file contains its decimal
value. Existing files are refused, and the host removes its own file after normal
shutdown. `hub --stop` acknowledges acceptance; the host then closes adapter
connections, cancels/joins hub work and exits. Signal-triggered graceful cleanup
has not been established on this runtime.

`serve --connect PORT` attaches the HTTP management API to the same nREPL owner.
It creates no local hub. Its connection closes when the HTTP server returns or
fails; stopping the HTTP process leaves the hub and its runs alive. HTTP uses
`--port` as a listen address, while `--connect` names the loopback nREPL port.
Without `--connect`, `serve` owns a hub and a loopback nREPL listener and connects
its HTTP adapter through nREPL. The default nREPL port is OS-assigned and printed
with a console attachment command; use `--nrepl-port PORT` to choose one. Model
options are shared with the other CLI commands; use `--mock` for no model calls.
Returning from HTTP serving or failing during listener startup closes owned
connections/listeners and stops the hub. The HTTP runtime still lacks an owned
server shutdown API, so graceful signal cleanup is not established. For an
independently stoppable hub, run `hub` and `serve --connect` as separate processes.
The adapter does not reconnect automatically after losing its hub connection.

The client classifies EOF before a reply as `:connection-closed`, unreadable or
uncorrelated replies as `:protocol-error`, and unclassified I/O failures as
`:transport-error`. Failures during a request include `:request_id` and
`:outcome_unknown true`: a missing reply cannot establish whether the hub acted.
The connection closes so late replies cannot be mistaken for a later request.

`attractor.nrepl-server/start!` now serves an existing hub on loopback, using the
local runtime's owned TCP listeners and bencode framing. Application operations
and lifecycle management remain let-go code.

```clojure
(require '[attractor.nrepl-server :as nrepl])
(def adapter (nrepl/start! existing-hub {:port 0 :max_clients 32}))
(:address adapter) ; actual {:host "127.0.0.1" :port ...}
;; Keep the owning host scope alive while clients use it.
(nrepl/close! adapter)
```

Closing a connection or adapter does not stop the supplied hub. Adapter close
closes its listener and every registered connection, then awaits worker cleanup.
The caller remains responsible for the hub's final `:hub/stop` request. Client
attachments made through `:client/attach` are hub identities independent of TCP
connections; clients explicitly detach them when finished. Reconnect can reuse
an attachment and request events from its last cursor.

Attach the existing console executable to the port returned by the host:

```sh
bin/attractor console --connect 4555
bin/attractor console --connect 4555 --tui
```

`--connect` takes a loopback port, not a URL. The host configures the hub's models
and workflow handlers; attaching does not create a second hub. `/quit` detaches
the client and closes its connection, preserving hub-owned work. Without
`--connect`, the command retains its existing in-process mode.

## Protocol

Messages and replies are bencode maps with string keys. Each request requires a
string `id`. `describe` advertises `describe` and `attractor/request`. CLI-owned
adapters additionally advertise `attractor/stop`; embedded adapters expose it only
with `:allow_stop true`. Stop is acknowledged before signaling the host. For example,
this let-go value is passed to `bencode/write!`:

```clojure
{"id" "open-1"
 "op" "attractor/request"
 "payload" "{:op :session/open}"}
```

The reply's `value` is an EDN string containing the hub's ordinary
`{:id ... :value ...}` or `{:id ... :error ...}` envelope. Its `status` is
`["done"]` or `["error" "done"]`; an unknown protocol operation additionally
reports `"unknown-op"`. The outer request ID always determines correlation.
Payloads must contain exactly one EDN map; reading data never evaluates code.

Supported hub operations:

- Evaluation submit and result, in the persistent hub console namespace.
- Workflow run, resume, list, result, inspect, events, checkpoint and cancel.
- Agent job run, list, result and cancel.
- Session open, list, submit, result and cancel.
- Question list and answer. `:question/answer` accepts either the existing
  string `:value`/`:text` fields or a complete `:answer` map, never both.
  Typed answers preserve `:yes`, `:no`, `:skipped`, `:timeout`, string values,
  freeform text, selected-option maps and metadata through EDN. Invalid
  answers are rejected before consuming the pending question. For example,
  `{:op :question/answer :question_id id :answer {:value :skipped :text "eof"}}`
  skips a human gate; the string `"skipped"` remains ordinary answer text.
- Client attach/detach, plus `:events/since` with `:client_id` and `:cursor`.

Submit/cancel replies omit completion promises. Use the returned run, job or turn
ID with its result operation. Session result lookup currently retains only the
latest turn and rejects older IDs. Request waits are bounded at five seconds;
a timeout does not revoke an admitted mutation, so retries are not automatically
safe. The adapter limits concurrent connections (32 by default). The EDN payload
limit is checked after bencode decoding; this is not a bound on frame allocation
or per-connection write time.

`:workflow/run` optionally accepts a nonnegative integer `:preparation_timeout_ms`.
The deadline belongs to the hub and limits admission through verified publication,
not the workflow's execution time. Inspection exposes `:admission` (`:pending`,
`:published`, `:failed`, or `:timed_out`). Expired preparation cannot later start
execution, even if the submitting client stops polling. Omission retains unbounded
preparation for native callers; HTTP submission supplies 30000 milliseconds.

`:workflow/inspect` returns a run's state, source, logs root, live context and
verified publication metadata (graph, diagnostics, fingerprint and manifest path).
These are snapshots from the hub-owned workflow, not a second execution registry.
Resumed runs expose the verified captured graph, canonical logs root and the
engine's live checkpoint-seeded context before execution continues. The returned fields do not claim
one atomic snapshot across concurrent context and result updates.

The dedicated inspection tests pass 21 assertions: a real handler is blocked
after updating context, and a second workflow resumes a saved checkpoint into a
human gate, exposes its saved/live state, then completes after an answer. The compiled host probe
also verifies graph and live current-node data over nREPL at a human gate.

Evaluation values may be functions or other process-local objects. For
`:eval/result` and successful evaluation events, the adapter sends `:value_repr`
(the printed representation) instead of raw `:value`, retaining `:printed`
stdout separately. The hub retains the original result. The console displays
the representation directly; it does not read or evaluate it. Evaluation jobs
are currently retained for the hub lifetime, like workflow and agent results.
This adds no evaluation cancellation capability to the underlying runtime.

## Evidence and remaining work

The console dispatcher can now attach through `attractor.nrepl-client` without
a local hub reference:

```clojure
(require '[attractor.nrepl-client :as client]
         '[attractor.console.session :as console])
(def connection (client/connect! {:host "127.0.0.1" :port hub-port}))
(def ui (console/open! nil (client/console-options connection)))
(console/handle! ui {:type :line :text "hello"})
(console/drain! ui)
(console/close! ui) ; detach hub client
(client/close! connection) ; close socket
```

The client serializes requests, validates outer and inner correlation IDs, and
closes the connection on I/O or malformed-response errors. It never retries a
mutation. Response reads have a timeout; lock acquisition and socket writes do
not yet have independent deadlines. Event-cursor expiry includes a recovery
position, so the console no longer reads hub memory to recover its event stream.
Remote text submission, response rendering and detach pass the native wire probe.

`make run-nrepl-hub` passes four tests/28 assertions for dispatch, exact EDN parsing,
correlation, cursor recovery, session results and printable persistent evaluation.
Console tests pass
nine tests/78 assertions. Existing hub tests pass 30 tests/
223 assertions. `test/probes/nrepl_hub_check.lg` passes with real loopback clients
both interpreted and bundled: shared session, disconnect survival, reconnect
result lookup, event replay and adapter cleanup. No model calls are made.

```sh
.worktrees/let-go-http-cancellation/build/lg -source-paths src test/probes/nrepl_hub_check.lg run
```

The CLI connection path passes two tests/nine assertions for selection, invalid
ports and lifetime. Existing CLI tests pass six tests/57 assertions. A rebuilt
`bin/attractor console --connect PORT`, driven by scripted `/new` and `/quit`, exits
zero and leaves its session open in the remote hub. Remote `: form` input works through the attached dispatcher,
including stdout and evaluation-result rendering in the native wire probe.
HTTP still owns a separate registry. Standard evaluation/session middleware, pushed event subscriptions,
historical turn results and stronger slow-client bounds remain unfinished. This
adapter is an explicit Attractor nREPL extension, not a claim of complete editor
nREPL compatibility or completion of the original Attractor specification.

Host tests pass three tests/ten assertions for argument validation, existing
port-file preservation and owned-hub cleanup on listener startup failure.
`test/probes/hub_host_check.lg` launches the compiled host, attaches the compiled
console, observes session survival, starts a workflow that waits at a human gate,
then invokes the compiled stop command and verifies exit zero and port-file
cleanup. The adapter probe also verifies embedded hosts reject stop by default.

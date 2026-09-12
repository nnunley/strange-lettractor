# Shared HTTP adapter status

`attractor.hub-http/make-handler` accepts a synchronous hub request function and
implements these existing HTTP controls without a private pipeline registry:

- `GET /pipelines` and `GET /pipelines/:id`.
- `GET /pipelines/:id/context` and `/questions`.
- `GET /pipelines/:id/checkpoint` and `/events` (SSE).
- `GET /pipelines/:id/graph` (SVG through Graphviz).
- `POST /pipelines/:id/questions/:qid/answer` and `/cancel`.
- CORS preflight.
- `POST /pipelines` with raw DOT or a JSON `dot` field.

Only runs with verified publication metadata are exposed. The adapter reads
workflow state and context from `:workflow/inspect`, and routes questions and
cancellation to hub operations. It verifies that an answer's question belongs to
the requested run. Status retains the existing HTTP status-string convention.

The hub now retains each run's event history for HTTP replay, in addition to its
bounded interleaved client log. `:workflow/events` accepts a run ID and optional
zero-based `:from` cursor and returns `:events` and total `:event_count`. Invalid
cursors are rejected. This per-run history currently has no eviction policy,
matching the old HTTP server's retention behavior.

Evidence: `make run-hub-http` passes four tests/51 assertions. A workflow submitted
through nREPL dispatch is listed and inspected through the HTTP handler, answered
through HTTP, and observed completed in the same hub. A second case verifies
wrong-run answer rejection, cancellation isolation, and event-history lookup.
These tests exercise the real pipeline and serialization but invoke HTTP/nREPL
handlers directly; they are not two-socket wire evidence. Inspection tests pass
2/22/0 as well. Graph assertions check the SVG content type, SVG markup, and the
submitted graph's title using real Graphviz output. Resumed inspection returns
the selected plan's DOT from its verified captured bundle; the adapter does not
open a source path in the hub's filesystem. Both HTTP adapters share the renderer
in `attractor.graphviz`.

The SSE test consumes an initial frame while a workflow is waiting, verifies the
remaining stream waits for completion, then checks the completion event and one
terminal frame. `Last-Event-ID` resumes at the next event; malformed/out-of-range
cursors return 400. The implementation rechecks history when completion races a
history read so it does not intentionally end before the final events. Checkpoint
data is fetched through `:workflow/checkpoint` inside the owning hub, not by
opening the host's path in the HTTP adapter process.

The idle stream emits `: keep-alive` SSE comments once a second using a monotonic
deadline. These carry no event ID and do not advance the replay cursor. Yielding
a chunk lets the local runtime's HTTP writer observe disconnection, instead of
polling indefinitely inside the lazy thunk. Hub requests still have their own
timeouts, so one second is not a hard upper bound on disconnect cleanup.

Native wire evidence: run
`.worktrees/let-go-http-cancellation/build/lg -source-paths src test/probes/shared_http_stream_check.lg run`.
This passed against real HTTP and nREPL sockets in an owned let-go child process.
The probe submits a human-gated workflow through nREPL, reads an idle heartbeat
through HTTP, closes the streamed response, waits 1.5 seconds for cleanup, and
checks that the last hub-history request timestamp stays unchanged for another
1.5 seconds. The workflow remains running; answering its question through nREPL
then completes it successfully. This is bounded inactivity evidence for the
tested close path, not proof of every network failure mode. The fixture process
is terminated and joined through its execution environment in cleanup.

Broader impact verification remains unresolved: `hub-console-ops` failed in two
runs. The captured rerun failed at the three-second human-question wait, followed
by missing-question/answer/completion failures (74 passing, 11 failing assertions).
Machine load averages were about 77–78 during these runs. Scheduling pressure is
a plausible cause, not a proven diagnosis. No test deadlines were relaxed.
Failure output: `/tmp/attractor-shared-http-impact.log`. A subsequent unchanged
recheck passed 13/85/0 (`/tmp/attractor-shared-http-recheck.log`). This removes the
current failing result but does not prove the diagnosis of the earlier timing
failures; no deadlines were changed.

Submission uses a hub-owned monotonic preparation deadline (30 seconds for HTTP).
The hub exposes `:admission` as `:pending`, `:published`, `:failed`, or
`:timed_out` through workflow inspection. Deadline expiration and verified
publication share the hub event lock. Once expiration wins, the publication
callback rejects execution even if no client continues polling. A published
run does not expire when its original preparation deadline passes. Failed and
expired attempts remain in the hub's diagnostic registry but are absent from
the HTTP list, which requires publication metadata. HTTP returns 201 only for
published runs and 400 for preparation failure or timeout.

Admission tests block real preparation before publication and verify that late
release cannot publish or emit engine events, both with and without inspection
during the delay. Native wire evidence also covers HTTP submission followed by
nREPL inspection of its verified publication and successful result.

Publication fault checks cover missing/corrupt manifests, wrong manifest paths,
a callback graph whose canonical plan fingerprint differs from the captured
graph, verification finishing after expiration, and concurrent duplicate
callbacks. Publication verifies graph identity as well as workflow identity;
matching duplicate callbacks preserve the first registration and diagnostics.
The admission suite passes six tests/36 assertions. Shared HTTP and inspection
suites pass 4/51/0 and 2/22/0, and the native shared socket probe passes after
these checks were added.

The CLI uses this adapter for both forms of `serve`. With
`serve --connect PORT --port ADDRESS`, it connects to an existing loopback nREPL
host and closes its connection in
`finally` when the HTTP server returns or fails, without stopping that host.
CLI tests cover normal return, bind failure, argument validation, and owner
survival (2 tests/18 assertions). Console connection and general CLI suites pass
2/9/0 and 6/57/0. `make build` succeeds, and the native `hub_host_check.lg run`
probe passes with compiled hub, HTTP adapter, console and stop commands: HTTP
submission is inspected through a separate nREPL client, then the adapter
process is terminated and joined while the hub remains responsive. Evidence
artifacts: `/var/folders/vk/rkcd0mjn591_03z0856412gh0000gn/T/hub-host-4b7e507f-8a71-4183-94b0-1ab9afe4aaa4`.
Unknown routes return 404. Before HTTP headers are sent, an unavailable or closed
hub connection returns 503; an invalid hub protocol response returns 502. Lost
responses include `request_id` and `outcome_unknown: true`, as does a hub request
timeout. The nREPL client closes a connection after transport/protocol failure,
without retrying a request or reconnecting. A request rejected locally because
the connection was already closed does not claim an uncertain submission.
Once SSE headers have been sent, failure yields a final `stream.error` event and
closes the response. Its data includes `run_id`, `next_event_id`, `category`,
`error`, and any available request correlation/uncertainty fields. It carries
no SSE ID, no workflow status, and no `end` event. It does not advance replay
history or imply that the workflow has completed. A client can reconnect through
a working adapter using its last received event ID.

Midstream evidence: shared HTTP tests pass 6/72/0. The native
`shared_http_stream_check.lg run` probe uses HTTP over an actual nREPL connection,
waits for an idle heartbeat, closes that nREPL server, and reads `stream.error`
followed by EOF over HTTP without an `end` event. A separate nREPL connection to
the same hub confirms the human-gated workflow is still running.

Integrated verification after the shared transport changes: `make test` passed
1036 tests, 9542 assertions, zero failures on the patched local runtime.
Log: `/tmp/attractor-shared-transport-suite.log`. This covers the current default
suite; it is not a fresh live-provider or upstream-runtime compatibility run.

Error evidence: nREPL client tests pass 1/32/0, shared HTTP tests 5/64/0,
and nREPL adapter tests 4/28/0. The native `nrepl_hub_check.lg run` probe closes
the real server side of a connected HTTP adapter's nREPL connection, observes
503 with uncertain outcome and request correlation, and verifies subsequent
requests reject the closed connection. `make build` passes.

A transport timeout can leave an already admitted
mutation running; the preparation deadline does not provide response delivery
acknowledgement or retract a published workflow.
Plain `serve` now owns one hub and an nREPL listener, then attaches HTTP through
that listener. `--nrepl-port` defaults to 0 (OS-assigned, reported on stdout).
The legacy `attractor.server` implementation remains as a reference and test
surface; CLI execution no longer selects its independent registry.

Migration evidence: CLI HTTP tests pass 4/44/0, general CLI tests 6/57/0, and
host tests 3/10/0. `make build` passes. The native compiled
`http_questions_check.lg run` probe verifies that HTTP submission and nREPL
inspection share a waiting workflow, then exercises HTTP answer routing,
question cleanup, and timeout defaults. Its ID assertion accepts the hub's
opaque `question-UUID` identifiers as well as the historical `q-UUID` format.
Signal-triggered graceful HTTP shutdown remains unproved on the local runtime.

# Hub Features — Consolidated

Current usage is documented in [hub.md](hub.md). This collection preserves
dated investigations: patched-runtime requirements and statements that HTTP
owns a separate registry are historical. Stock let-go 1.13.0 supplies the
listener; `hub`, `console --connect` and `serve --connect` share a hub today.

## Hub Listener Runtime Request

# Runtime request: owned TCP listeners for a let-go RPC hub

Original request: independently reviewed; acceptance details posted on existing
[let-go #523](https://github.com/nooga/let-go/issues/523#issuecomment-5579712836).
Update 2026-09-12: implemented locally as `runtime-patches/net-listener.patch`.
The native `test/probes/net_listener_check.lg` passes both as a script and a
standalone bundle. It verifies port zero, bind errors, two bencode clients,
fragmented/coalesced frames, close waking accept/read, idempotent listener close
and accepted connections surviving listener close. Existing runtime TCP/bencode
tests also pass. This is an explicit-close primitive; automatic scope ownership
and the nREPL adapter are not implemented by it. The historical findings below
describe the runtime before this patch, not the configured binary now.

Strange Lettractor needs a long-lived hub that owns agents/workflows while
terminal clients attach and detach independently. Product code, including
protocol dispatch and supervision, must remain let-go.

This preserves the library-first/event-driven boundaries in the snapshot
`coding-agent-loop-spec.md` sections 1.2–1.3 and the streaming-first SDK principle
in `unified-llm-spec.md` section 1.2. A new hub protocol does not replace the
existing HTTP/SSE conformance obligations in `attractor-spec.md` section 9.5.

## Verified gap

Local `lg` dev bdd8268 reports `(close! dial read! write!)` for
`(sort (keys (ns-publics 'net)))`. The native `net` wrapper has no listener.
Existing bencode read/write accepts the private native connection wrapper, so
exposing an arbitrary reflected Go net.Conn alone would not establish bencode
compatibility. Stock nREPL dispatch is not extensible; see the companion findings.

Upstream #523 already proposes server-side sockets; #525/#526 delivered the
TCP client and bencode only. This request makes that follow-up concrete, rather
than proposing another networking namespace or a Go product server.

## Proposed minimal language contract (names subject to upstream review)

- `(net/listen host port)` returns an owned TCP listener. Explicit host required;
  our hub passes `127.0.0.1`. Port zero binds once and permits OS allocation.
- `(net/local-address listener)` returns host and actual bound port as data.
  Do not reserve a port separately and introduce a free-port/bind race.
- `(net/accept listener)` returns the same connection representation as dial,
  usable with existing net and bencode operations.
- `(net/close! listener)` is idempotent and wakes a blocked accept. Closing a
  listener does not implicitly close already accepted connections: the hub's
  supervisor owns those separately. Existing connection close remains available.
- Accept/listen failures surface as catchable let-go errors using the runtime's
  normal value/error contract. No process exits or panic-only API.
- Preserve native/WASM gating; unsupported targets fail explicitly.

## Mechanical acceptance

Native let-go test starts loopback port zero, discovers the actual port, accepts
two clients, and exchanges multiple coalesced/fragmented bencode frames through
the existing decoder. Assert the existing normalized value contract (keywords
become strings, lists become vectors, dictionary keys become strings), not exact
let-go value identity. Round-trip supported frame values without encoding nil,
booleans or floats into bencode silently. Application values can be explicit EDN
payload strings; protocol choice must not weaken the reader contract.

Use bounded synchronization to prove closing the listener wakes accept, repeated
close is harmless, an accepted connection survives listener close, and closing
that connection wakes its blocked read. Join owned tasks; no sleep-only ordering,
free-port probing, detached timeout future, fixed test ports or leaked listeners.
Test bind failures and failed accept as catchable values/errors. Run the same
fixture from a standalone bundle, without claiming native-Go AOT parity.

## Scope and alternatives

This is a primitive gap, not a reason to rewrite the framework in Go. The
documented lginterop/gogen tooling exists and can generate Go wrappers, but those
must be registered in a custom runtime build; they are not dynamically loadable
imports in the current stock lg. A native net.Conn wrapper also differs from the
existing net/bencode handle representation. We have not proved that generated
wrapper route end-to-end, so do not call it impossible or silently substitute it.

HTTP request/response is available today, but the current http/serve path buffers
responses and hides server shutdown. Polling it would not prove the intended
streaming hub. Extending the listener primitive lets the hub protocol, request
registry, event subscriptions and supervision live in `.lg`. Do not duplicate
existing upstream interruption/session issues #586/#589/#592 in this request.

Next product work can proceed on the hub's actual agent/workflow ownership API
with in-process public integration tests. Wire-level streaming, disconnect and
reconnect remain explicitly unproved until a usable transport exists.

---

## Hub Session Plan

# Hub-owned agent sessions: implementation and evidence plan

Status: in-process agent-ownership component implemented and mechanically verified.
The user-requested Claude connector shipped first as 84c3b7a and was used for the
origin implementation and a bounded read-only review. RPC, eval, workflows and
worker attachment remain follow-on integrations, not completed by this component.

## Goal and boundary

Implement the framework-facing session owner behind the console's RPC boundary.
This is real Attractor agent integration, not an RPC-shaped mock. The hub owns
agent sessions and turn workers; client attachment owns only observation state.
Transport, workflow launch/recovery, explicit evaluation, external CLI workers
and terminal rendering remain required follow-on integrations. Do not mark the
whole CONSOLE-HUB-01 story complete from these in-process tests.

## Ownership architecture

A hub supervisor runs a mailbox loop in a native let-go future. It opens a child
scope and launches all agent turn futures from that loop, never from a client
request's dynamic scope. The host must keep the hub supervisor's parent scope
alive for the service lifetime. Closing a per-client scope cannot cancel hub
turns. No async helper known to escape scope ownership is used (#806).

The supervisor serializes admission and session/client registry changes. Agent
callbacks only append identified events to a bounded shared event log; they must
not wait on mailbox replies or invoke client callbacks. Slow clients cannot
block the agent callback. One writer lock protects sequence allocation and append;
do not rely on collection CAS/swap-vals! while upstream #824 remains open.
Install exactly one session-level `:on_event` listener; do not also pass a
per-turn listener. Capture the current hub turn ID under the event writer lock,
including session start/end with no turn when appropriate. Envelopes identify
`:source :agent`; later workflow/eval/worker sources remain separate.

The delivery-time capture sentence above is superseded by the proposed emission
origin amendment below: actual child forwarding proved it insufficient.

Mailbox admission is bounded and nonblocking: under a short boolean-CAS admission
lock, reject stopped hubs or a full mailbox with an already-resolved error reply;
otherwise use native `async/offer!`. Never hold that lock during agent operations.
Shutdown closes admission under the same lock, then resolves every queued request
behind stop as stopped before draining workers. Repeated stop shares the shutdown
completion, including while shutdown is in progress. No blocked enqueue callers.
The supervisor itself stays outside the child scope it drains.

Worker completion uses a tagged result promise, resolved on every exit path.
This includes failure while launching the future after admission. Busy means
the prior turn promise is not yet realized, not merely agent state processing;
processing_end may precede that promise. Submit first checks actual agent closed
state as well as explicit hub cancellation, covering provider error and tool-hook
closure. Never launch another turn into a self-closed agent.
Do not publish completion by enqueueing into the supervisor's bounded mailbox:
shutdown could otherwise await a worker blocked on that same mailbox. Closing a
session remains terminal even if an uncooperative provider returns success late.
Explicit cancel marks hub session closed before starting abort in a hub-scoped
future; abort/cleanup must not stall the admission loop. Its reply identifies the
session plus an in-process cancellation completion promise. Late success while
closed is tagged cancelled, not successful. Shutdown starts aborts for all sessions
before draining, so one slow cleanup does not prevent cancellation of siblings.
Hub shutdown rejects new work, aborts all sessions outside event-log locks,
closes/drains its scope, then resolves the shutdown completion. Do not report
quiescence on a drain timeout; uninterruptible providers remain a known limitation.

## Public API proposal

Create `src/attractor/hub.lg`; one service module, not a generic actor framework.

- `start! [opts]` returns a hub handle after supervisor readiness. Options include
  positive event capacity and trusted session defaults, not remote code strings.
- `request! [hub request]` returns a reply promise. Request maps have an opaque
  request ID and an operation. Replies carry that same ID and either `:value` or
  `:error` data. No caller-timeout means rejection: waiting clients may time out
  without implying an already admitted request was cancelled. Reject requests
  after shutdown without leaving unresolved promises. Invalid/unknown requests
  get explicit error replies and do not terminate the supervisor.
- Operations: `:session/open`, `:session/list`, `:session/submit`, `:session/cancel`,
  `:client/attach`, `:client/detach`, `:hub/stop`.
  Here session always means Attractor agent session, never an nREPL eval session.
- Open uses actual `agent/make-session` with trusted startup configuration;
  submit launches actual `agent/process-input!` and returns a stable turn ID plus
  a completion promise at the in-process seam. A later wire adapter converts this
  to an ID, not a serialized promise. Only one active turn per session; concurrent
  duplicate submits fail explicitly as busy, never silently queue extra work.
- Attach returns a client ID and the current newest cursor; clients may explicitly
  request earlier retained history. Detach removes observation membership only. It
  never calls agent abort/close. Unknown client/session IDs fail explicitly.
- Cancel names a specific session and closes it using the existing agent API.
  This does not claim reusable-session soft interruption that the agent API lacks.
- `events-since [hub client-id cursor]` returns identified events after an exclusive
  monotonic cursor plus the newest cursor. Reject unknown clients, negative/future
  cursors, and expired cursors explicitly; never silently skip overwritten events.
  Each envelope contains hub sequence, agent session ID, turn ID where applicable,
  and the original event data. This is a replay API, not wire-streaming proof.

Request IDs are correlation only in this component. Document that retried mutations
are not deduplicated yet; network retry/idempotency policy is required before RPC
integration. Do not imply exactly-once execution.

## Acceptance and mechanical proof

Story component CONSOLE-HUB-01A; scenario SCN-HUB-AGENT-OWNERSHIP. Public integration
tests in `test/attractor/hub_session_test.lg`, focused runner
`test/runner.lg attractor.hub-session-test`. Native let-go fixtures; no handwritten Go/Python server.

1. Actual fixture-provider agent session completes a tool-free turn and a follow-up
   with preserved history. Observe session/turn-tagged events before final completion.
2. Open two sessions, interleave bounded provider gates, and verify event identity,
   sequence ordering and independent results. Busy admission invokes provider once.
3. Submit from a short-lived client scope, detach/close that scope, then release
   the provider gate; the hub-owned turn still finishes and a new client sees it.
4. Cancel one running session while a sibling finishes; late provider completion
   cannot resurrect the closed session or admit a later turn.
   A provider-error/self-closed session also rejects later submits as closed.
5. Unknown operations/IDs and malformed requests return correlated error data;
   next valid request works. Stop-vs-admission leaves no unresolved reply promise.
6. Stop with active native blocking workers: abort resources, join the owned scope,
   then acknowledge shutdown. Repeated stop is idempotent. No orphaned work or
   client callbacks under locks. Every test releases gates in finally and joins.
7. Small event capacity forces rollover: expired cursor errors explicitly; valid
  cursor resumes without duplicates/gaps. Detach revokes observation access.

Cursor boundary: if oldest retained sequence is N, cursor N-1 is valid; smaller
cursors are expired. Snapshot events and newest sequence atomically. Test mailbox
saturation and requests already admitted behind stop, not just sequential stop.

Use bounded promises/barriers, not timing-only sleeps. Record failing assertions
before implementation. Focused command:
`/Users/ndn/development/let-go/lg -source-paths src:test test/runner.lg attractor.hub-session-test`.
After code freezes, run impacted agent/lifecycle tests, full local-lg `lgx test`,
outside-checkout focused bundle and CLI build/help. Paired spec/quality/audit gates
precede commit and public push. Baseline before this component: 686/6705/0.

## Event-origin amendment (scope approved)

An actual built-in `spawn_agent` fixture holds the parent's callback drainer while
the parent completes. Its queued `processing_end` then arrives after the hub has
cleared the turn ID. A later turn can likewise steal old events. A drain barrier
does not establish provenance for a continuing child; origin must travel with
the event before enqueueing.

Proposed bounded change:

- Add optional dynamic `agent/*event-origin*`, default nil. Stamp its immutable
  value as `:origin` before enqueueing each event, including explicit nil. This
  is trusted host context, never read from model-produced event payloads.
- Hub binds `{:hub_turn_id turn-id}` around actual `process-input!` and derives
  envelope turn identity only from stamped origin, with no mutable-state fallback.
  Session open explicitly binds nil. Existing wire/session IDs remain unchanged.
- Child forwarding explicitly binds the nested event's origin, including nil,
  before emitting its parent wrapper. Never infer origin from the active drainer.
- Capture origin alongside each admitted child input, including queued sends.
  The worker binds that input's captured origin when processing it. A continuing
  child spawned by A retains A; input sent later by B has B origin even if consumed
  by the same native worker. Child session identity remains the existing nested
  `:agent_id` and `:session_id`, not a fabricated hub child turn.
- Explicit cancel/stop captures the unfinished target turn under the same lock
  as cancellation/publication, then binds that origin around asynchronous abort.
  Completed/idle session closure explicitly uses nil; provider-error closure
  naturally retains the executing invocation's origin. No callbacks under locks.
- No callback-drain wait, new transport, runtime edit, or additional event listener.

Extend implementation ownership to `src/attractor/agent.lg` only after scope
approval. Existing hub tests plus native agent/subagent regression tests must prove
delayed parent A events retain A after B admission, nested child A forwarding
retains A, queued B child input has B origin, explicit nil is not borrowed from an
unrelated drainer, and active versus idle cancellation/end identity is correct.
Preserve callback self-close safety and existing scoped child admission/cleanup.
Run impacted lifecycle tests and full default suite after the amended candidate
passes paired spec and quality review; the original whole-goal backlog stays open.

Scope approvals: Planck and actual Claude Code read-only review, both completed.
Additional obligations: remove the obsolete hub log `:turns` map entirely; bind
origin inside each worker body; preserve explicit nil and the independent
`*delivering-session-ids*` callback ancestry; rerun existing agent event assertions
after adding the origin field. No global listener-context rebinding is needed.

Final evidence: focused native and outside-checkout bundle 20/149/0; affected
agent/lifecycle 166/1044/0; full default suite 719/6926/0; build/help pass. Live
tool-free Qwen hub detach/re-attach smoke returned text and retained identified
events, then joined shutdown. See console-requirements.md for scope/limitations.

---

## Hub Worker Findings

# Hub-owned Claude workers: implementation discovery

Status: discovery complete; proposed integration awaits scope approval. This is
not an implemented worker registry or proof of separate-process RPC.

Rechecked local let-go on 2026-09-08: checkout remains `bdd8268c9`, and
`pkg/rt/net.go` still exports only dial/write!/read!/close!. The listener gap
documented in `hub-listener-runtime-request.md` remains. No runtime files changed.

The existing hub owns agent sessions. The existing Claude connector owns a real
subprocess and joins it before returning, including cancellation and failure.
Connecting these two existing components can proceed independently of transport.

## Recommended boundary

- Add `:worker/start`, `:worker/list`, and `:worker/cancel` to the existing hub.
  One-shot jobs are not Attractor agent sessions or reusable Claude sessions.
- Trusted startup profiles select command, working directory, model, tools,
  permission mode and timeout. A start request selects a profile and supplies a
  prompt. Reject unsupported request fields rather than silently accepting an
  attempted executable, callback or permission override.
- Allocate a hub job ID before launch, retain it through completion, and launch
  only from the supervisor. Preserve connector worker/session IDs as separate
  nested identities in events. Generalize the shared log append function without
  changing existing agent envelopes, cursor boundaries or event ordering.
- Detach changes observation only. Explicit cancellation marks the job under
  the final-publication lock and supplies the connector's cancellation predicate.
  Use the job's completion promise as the join point; no redundant abort future.
  A cancellation that wins publication must preclude late success. Cancellation
  after completed success must not rewrite history.
- Signal all active jobs and sessions before waiting for any of them. Await job
  completion (which includes connector cleanup/join) before draining the native
  hub scope. Do not infer process quiescence from a cancellation flag or timeout.
- Connector protocol/result events remain distinguishable from authoritative hub
  job completion: a connector result can precede cleanup or lose a cancellation
  race. An observed protocol result alone must not label the hub job successful.
- Completion promises stay in process. Authentication, request deduplication,
  wire framing, subscriptions and a console command remain separate obligations.

This uses the existing hub and connector rather than adding a generic actor
system or a second worker implementation. Waiting for listeners would delay an
independent integration; routing Claude through `agent/process-input!` would
incorrectly treat its already-owned tool loop as a model completion.

## Mechanical acceptance for the implementation

Use the real let-go subprocess fixture, not a replaced worker function:

1. Successful start/list/completion and replay identify the correct hub job and
   preserve connector identity, including events observed before completion.
2. Two gated jobs interleave independently; a short-lived client detaches and
   closes its scope without cancelling either. Another client recovers events.
3. Cancel one gated/late-writing job while a sibling succeeds; await actual
   completion and verify no surviving late write. Unknown IDs fail explicitly.
4. Hub stop with multiple active jobs signals all, joins them, and realizes every
   completion before acknowledging stop. Include launch/failure paths.
5. Completed success remains success after cancellation. Gate final publication
   to exercise cancellation winning after connector computation but before
   publication; a protocol result is not sufficient to win that race.
6. Unknown profiles and attempted command/tool/callback overrides fail before
   launching any subprocess; a subsequent valid request still succeeds.
7. Protocol/nonzero/timeout errors retain typed failure and leave no busy job or
   hung shutdown. Rerun agent ownership tests to protect the shared event log.

## Discovery provenance and adjudication

Actual Claude ran read-only through `bin/attractor claude`, using four explicitly
named source/fixture files, session `526da7c6-a93e-490e-ada9-539b06f97648`, exit 0.
No edits or tests were delegated in this discovery. Main inspected the execution
environment's registration and cleanup paths as well.

Accepted: reuse job completion for cancellation join; profile-only configuration;
separate job identity; generalize the existing event append path. Corrections:
the proposal never required a second abort future for jobs; reject rather than
ignore unexpected request fields. Await-before-scope-drain is the proposed
ownership order, not a newly reproduced runtime bug. A missing marker alone is
not enough unless the test also proves the worker completed and was joined.

---

## nREPL Hub Investigation

# nREPL hub capability investigation

Later 2026-09-12: local `net/listen`, `net/local-address`, `net/accept` and listener
close are now implemented and pass native/bundled wire checks. The tracked patch
is `runtime-patches/net-listener.patch`. This resolves the local primitive gap;
it does not change stock nREPL dispatch or establish the product's nREPL adapter.

2026-09-12 recheck: the configured runtime still exposes only `close!`, `dial`,
`read!`, and `write!` in `net`; its nREPL dispatch remains fixed and interrupt
remains a response-only stub. The user reaffirmed nREPL for let-go clients and
HTTP for other clients, sharing one owner. See
[shared-hub-transport-plan.md](hub-features.md) for current code
evidence and the migration sequence.

The console must be an RPC client, not the framework owner. The stock local
let-go nREPL is not yet a sufficient framework hub transport.

Inspected local `pkg/nrepl/server.go` and `pkg/rt/bencode.go`; live runtime banner
reported dev bdd8268. These findings describe this checkout, not every nREPL
implementation or a completed Attractor integration.

- Server binds loopback and supports OS-assigned port discovery.
- Operation dispatch is a fixed Go switch; no custom handler registration was
  found in that server. An `attractor/sessions` request returned unknown-op.
- Eval buffers output and emits it only after CompileMultiple returns. A bounded
  eval printing before a 500ms wait produced no response within a 50ms read.
- Interrupt handler only responds done/session-idle; it does not signal the eval.
  A separate connection requesting interrupt during that bounded eval received
  session-idle. Do not use this as framework cancellation.
- Eval uses the shared compiler context rather than looking up the supplied
  session. A request naming a nonexistent session successfully evaluated (+ 40 2).
  Session isolation and unknown/closed-session rejection need separate contracts.

Live probe: `/tmp/lettractor-nrepl-probe.AIcFXP/probe.lg`, native let-go only,
1 test / 5 assertions / zero failures, exit 0. These assertions confirm observed
limitations, not desired acceptance. A subsequent run strengthened the timeout
assertion to require a timeout diagnostic, and took the actual ephemeral port as
an argument: 1/5/0, exit 0. Source inspection remains stronger evidence for the
buffering/interrupt implementation than this time-bounded wire observation; the
probe is not a comprehensive upstream session-isolation regression suite. The
owned loopback server was stopped after both runs. No runtime source edited.

## Next decision

Evaluate a let-go-owned extensible nREPL hub using existing net/bencode facilities
versus a framework RPC channel alongside stock nREPL for explicit trusted eval.
Do not encode all commands as arbitrary eval just to reuse the existing server.
Preserve `.edn` application data; nREPL bencode framing does not by itself change
the application's serialization policy. Authentication/local permissions,
subscription backpressure, request IDs, cancellation and reconnect/replay must
be explicit before choosing the hub contract. Upstream issues should use isolated
reproducers and be checked for duplicates.

Existing upstream breadcrumbs (verified open):

- [#586: embeddable nREPL and shared sessions](https://github.com/nooga/let-go/issues/586).
- [#589: evaluation interruption / nREPL interrupt stub](https://github.com/nooga/let-go/issues/589).
- [#592: per-evaluation output and namespace routing](https://github.com/nooga/let-go/issues/592).

No duplicate issues filed. These proposals primarily discuss Go embedding;
our product remains let-go and needs a language-level extension surface.

The stock `net` namespace also lacks listen/accept; details and the reviewed
upstream request are in `hub-listener-runtime-request.md`. Neither the existing
HTTP server nor stock nREPL is a proved streaming hub substitute.

---

## nREPL Hub Reference

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

---

## Hub Transport

# Hub Transport — Shared HTTP & nREPL Plan

## Shared HTTP Adapter

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

---

## Shared Hub Transport Plan

# Shared hub and nREPL transport

User direction, reaffirmed 2026-09-12: let-go clients communicate through nREPL.
Retain HTTP management semantics for other clients. Both adapters must reach the
same hub-owned runs, questions, sessions, cancellation and event history.

## Current evidence

The native nREPL adapter and client pass real two-client, disconnect/reconnect
and shutdown checks. The console dispatcher uses injected request/event functions
when attached, including remote evaluation with preserved stdout and printable
results. `console --connect PORT` (optionally `--tui`) selects this path. A compiled
line-console probe confirms `/quit` leaves the hub and its session alive. See
[nrepl-hub.md](hub-features.md) for exact evidence and limitations.

- Without `--connect`, `cli.lg` still creates and stops an in-process hub.
- `server.lg` owns a separate `active-pipelines` registry and starts pipelines
  independently. Its recent HTTP fixes do not establish shared ownership.
- Hub run, submit and cancel replies retain internal completion promises; the
  nREPL adapter strips them and exposes ID-based result lookups.
- The configured local runtime now supports owned TCP listeners with native and
  bundled acceptance evidence; see `runtime-patches/README.md`.
- The current local `pkg/nrepl/server.go` still dispatches a fixed operation
  switch, and interrupt returns session-idle without interrupting execution.
  Older findings therefore cannot be treated as resolved by newer HTTP patches.

## Implementation sequence

The shared HTTP control adapter now reads and mutates hub-owned runs without its
own execution registry. Handler-level cross-transport tests pass for status,
context, questions, answers and cancellation. It is not wired into the CLI:
submission admission, graph/checkpoint routes and SSE remain pending. See
[shared-http-adapter.md](hub-features.md).

`:workflow/inspect` now supplies new runs' live context and verified publication
metadata from the hub owner, with native and compiled nREPL evidence for fresh
runs. Resumed runs now expose the same live context/publication fields through a
verified resume observer, tested through the hub. HTTP admission timeout races
remain to be carried over.

First implemented increment: `:workflow/result` now looks up a run by ID and
returns `:running` or `:completed` with the existing result envelope, without
blocking or exposing its completion promise. Success, running, cancellation and
unknown-run behavior pass hub tests. `:agent/result` now uses the same snapshot
contract. `:session/result` additionally requires the current turn ID and rejects
missing or stale IDs, so it cannot silently return another turn. Session history
is not retained yet. Evaluation result lookup and the native transport also
exist now. `hub --port PORT` and `hub --stop PORT` provide a persistent CLI host
with compiled startup/attachment/shutdown evidence. HTTP adaptation remains
unfinished. See
[the result-operation plan](superpowers/plans/2026-09-12-hub-workflow-result.md).

1. Give the hub a data-only remote operation boundary. Preserve internal promise
   ownership; return stable job IDs and explicit running/terminal result data.
   Route question answers and cancellation through existing hub operations.
   Extend workflow inspection to expose context, graph and checkpoint data
   required by HTTP without creating a second registry.
2. Add the owned listener primitive described in `hub-listener-runtime-request.md`
   to the runtime, preserving a tracked reproducible patch. Verify port-zero
   binding, compatible bencode connections, close waking accept/read, and cleanup
   using native let-go clients. Product operation dispatch stays in let-go.
3. Implement explicit nREPL operations over that transport, retaining request
   correlation and standard completion/error statuses. EDN payloads carry
   application values that bencode cannot represent directly. Keep Attractor
   agent/session IDs distinct from evaluation-session IDs. Evaluation is an
   explicit operation; ordinary commands are not encoded as arbitrary eval.
4. Make the console attach to the hub through nREPL. Client detach must leave
   work running; explicit cancellation targets hub-owned IDs. Verify event
   replay and expired cursors across reconnects using two real clients.
5. Adapt HTTP endpoints and SSE to that same hub instance, preserving existing
   routes, publication validation and timeout semantics. Retire independent HTTP
   pipeline ownership only after cross-transport tests prove the replacement.

## Acceptance evidence

Start one owned hub with both adapters. Start a workflow from nREPL, inspect and
answer its human question through HTTP, and observe the same completed run from
both clients. Repeat with HTTP submission and nREPL answer/cancel. Disconnect one
client during work, reattach and recover events without cancelling the run.
Exercise parallel questions, timeout defaults, invalid IDs, cancellation races,
slow subscribers and shutdown cleanup. Use behavior and actual result data as
assertions. No fixed test-count assertions or Python clients.

The existing HTTP adapter remains available during this migration. Its successful
wire probe is adapter evidence, not evidence of nREPL integration. This plan also
does not close the original-spec audit or the provider/runtime release gaps.

---

---

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
`dev/hub_session_tests.lg`. Native let-go fixtures; no handwritten Go/Python server.

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
`/Users/ndn/development/let-go/lg -source-paths src:test dev/hub_session_tests.lg run`.
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

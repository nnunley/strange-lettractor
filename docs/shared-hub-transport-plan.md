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
[nrepl-hub.md](nrepl-hub.md) for exact evidence and limitations.

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
[shared-http-adapter.md](shared-http-adapter.md).

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

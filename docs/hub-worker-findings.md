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

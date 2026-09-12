# Runtime execution audit — 2026-09-12

This audit compares the original Attractor spec's execution and handler contracts
with current code and tests. It is one part of the completion audit, not a
full-spec certificate.

| Contract | Inspected evidence | Finding |
|---|---|---|
| §11.3 start, traversal, dispatch, terminal outcome | `engine_test.lg`, `parity_test.lg`, `handler_matrix_contract_test.lg`; engine dispatch and stage status writing | Existing execution and handler-matrix coverage; fresh engine run passes 46/209 after the fix below. |
| §11.4 goal-gate enforcement | `test-goal-gate-enforcement`, parity cases 10/11 and resume gate outcomes | Existing success, retry-target and failed-exit evidence. No new defect identified in this inspection. |
| §11.5 retry limits/backoff/jitter | Engine policy construction and delay calculation; `test-pipeline-retry-policy-controls-backoff-without-real-sleep`, named policy limits and jitter test | Existing executable checks. Returned FAIL follows the documented project interpretation of normative §§3.5/3.7, rather than the contradictory checklist wording; `fail_retry_contract_test.lg` records it. |
| §4.11 manager child execution with §3.1 lifecycle and §8 stylesheet | `make-child-runtime`, manager handler and real-child tests | Defect found: child source was parsed and executed without transforms or validation. Fixed and verified below. |
| §2.7 loop restart with §9.5 HTTP checkpoint/context inspection | `hub_workflow_inspection_test.lg`, `pipeline` restart publication callback, hub checkpoint operation | Defect found: hub retained the first segment's log root and manifest, so HTTP read an obsolete checkpoint after restart. Fixed for both fresh and resumed workflows. |

The manager regression uses a real child DOT file and default runtime. Before the
fix, a valid child's `llm_model` stylesheet selection was missing, and a child
without an exit node executed its work handler and let the parent succeed. Three
assertions failed. The manager now applies built-in transforms and raises on
validation errors before creating the child runtime or launching its worker.

Verification:

- `make run-engine`: 46 tests, 209 assertions, zero failures.
- `make build`: successful native CLI build.
- Full suite passes. After removing the fixed test-count assertion at the user's
  request, the engine tests and final-form reader guard also pass in a focused run.
- Compiled CLI, real-file parent and child: valid child exits zero, its prompt
  contains the expanded `Do ChildGoal`, and its checkpoint exists. Invalid child
  exits one and creates no work-stage prompt. Model execution was mocked.
- Probe artifacts: `/var/folders/vk/rkcd0mjn591_03z0856412gh0000gn/T/attractor-manager-audit-xwy7kgl5/`.

This does not establish captured-bundle recovery for manager child source,
inheritance of caller custom transforms into manager children, live model quality,
or completion of the other two specifications. The full completion audit remains
open. Story status alone missed this cross-feature defect.

## Restart inspection follow-up

The new regression runs a real workflow through a restart edge and holds its
second segment at a human gate. Before the fix, hub inspection returned the old
log root and manifest, and checkpoint lookup returned the previous segment's
context. Three assertions failed. The pipeline now provides a wrapper-only
`:on-restarted` observer after publishing the captured bundle in the new root.
The hub verifies publication and the existing workflow fingerprint, then updates
the active log root and manifest under its event lock. Event payloads alone do
not redirect filesystem reads. Both fresh execution and checkpoint resume use
this observer.

Evidence: hub inspection 3/34/0; loop restart contracts 10/198/0; workflow recovery
contracts 52/481/0; CLI 6/57/0. The regression checks the actual checkpoint's
second-segment context while the run is still active, including a resumed run
that immediately crosses a restart edge. These are component/integration tests;
the restart-specific case has not been repeated over HTTP sockets.

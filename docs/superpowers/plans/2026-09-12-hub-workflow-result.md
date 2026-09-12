# Hub workflow result implementation plan

Goal: expose an existing hub-owned workflow's result by ID without returning a
completion promise or blocking the hub's request worker.

Architecture: add `:workflow/result` to `hub.lg`. Read the registered completion
promise with a zero timeout and return `{:run_id id :state :running}` or
`{:run_id id :state :completed :result result}`. The result preserves the existing
value/error envelope; completed does not mean successful. Unknown IDs use the
existing `:unknown-run` error. This is the first step of the shared transport plan,
not a complete remote operation boundary.

Tech stack: native let-go, existing hub mailbox and workflow fixtures.

- [x] Extend `hub_console_ops_test.lg` to inspect completed success and a blocked
  running workflow, then inspect cancellation. Verify a request ID is preserved
  and unknown runs fail explicitly.
- [x] Run the namespace and observe unknown-operation failures.
- [x] Implement nonblocking result inspection in `hub.lg`.
- [x] Rerun hub console and session tests; document exact limits.

Verification: four new behavioral assertions failed before implementation. After
implementation, hub-console-ops passes 13 tests/81 assertions and hub-session
passes 17 tests/132 assertions. `git diff --check` passes. No new compiled CLI or
wire test was run for this operation; the console still uses its internal API.

Existing submit/cancel promise responses remain internal compatibility surfaces.
Transport adapters must omit those promises and use result lookup; no wire
adapter or remote-client behavior is claimed by these tests.

Next increment: use the same completion snapshot for `:agent/result` and
`:session/result`. Agent lookup takes `:agent_id`; session lookup takes both
`:session_id` and `:turn_id`. The current hub retains only its latest turn, so
missing/stale turn IDs must fail as `:unknown-turn`, never return another turn's
result. Historical result retention remains a separate reconnect requirement.
Extend real session and subprocess fixtures for running, success, failure,
cancellation and identity errors, observe failures, implement and rerun both
hub namespaces.

Implemented and verified: ten new assertions failed before the two operations
were added. Hub-session now passes 17 tests/138 assertions; hub-console-ops passes
13 tests/85 assertions. Workflow lookup shares the same nonblocking snapshot
helper and its existing tests still pass. These are in-process public API checks,
not proof of nREPL serialization, streaming or historical result retention.

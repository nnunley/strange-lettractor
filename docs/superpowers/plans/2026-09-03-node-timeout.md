# Node Timeout Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce Attractor node deadlines per execution attempt and make ToolHandler commands shell-correct and killable.

**Architecture:** `execute-with-retry` owns an attempt cancellation controller and deadline wrapper, while prepared nodes expose a combined cancellation predicate to handlers. ToolHandler delegates commands to the existing local execution environment; the agent codergen backend converts the predicate into session abort and full-fidelity eviction.

**Tech Stack:** let-go 1.12.2+, lgx tests/build, existing `attractor.parser`, `attractor.execution`, and `attractor.agent` modules.

**Design:** `docs/superpowers/specs/2026-09-03-node-timeout-design.md`

---

## Chunk 1: Engine attempt deadlines

### Task 1: Validate and expose node timeout durations

**Files:**
- Modify: `src/attractor/engine.lg`
- Test: `test/attractor/engine_test.lg`

- [ ] **Step 1: Write failing duration tests**

Add focused `execute-with-retry` tests proving `timeout="20ms"` stops waiting,
signals `(:cancelled? node)`, returns a timeout failure without retries by
default, and rejects invalid/non-positive explicit timeouts.

- [ ] **Step 2: Run the focused engine suite and verify RED**

Run: `env LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/engine_test.lg`

Expected: timeout tests fail because handlers currently run synchronously and
receive no cancellation predicate.

- [ ] **Step 3: Implement the per-attempt deadline wrapper**

In `src/attractor/engine.lg`, add a private timeout resolver using
`parser/parse-duration-ms`. For every attempt, create an atom-backed controller,
associate `:cancelled?` and `:cancellation_reason` onto the node, execute the
handler in a future only when a timeout is set, and dereference it with the timeout.
On expiry, signal cancellation, join the handler, and surface an `ex-info` carrying
`{:category :timeout_error :retryable true :node_id node-id}`.
Poll at a short bounded interval so pipeline cancellation is observed while a
handler is active; atomically give `:pipeline_cancelled` precedence over
`:deadline`.
Capture a joined handler's structured `:context_updates` in the timeout
exception and have `execute-with-retry` merge those details into its timeout
Outcome; never accept a late success after the deadline.

- [ ] **Step 4: Run the engine suite and verify GREEN**

Run the command from Step 2. Expected: all engine tests pass.

### Task 2: Prove timeout retry behavior

**Files:**
- Modify: `test/attractor/engine_test.lg`
- Modify: `src/attractor/engine.lg` only if the new test exposes a defect

- [ ] **Step 1: Write a failing retry test**

Use `max_retries=1` and a cooperative handler. Assert two distinct attempts,
two cancellation signals, `:stage.failed` with `:will_retry true` before one
`:stage.retrying` event, and a final timeout failure. Add pipeline cancellation
during an active attempt, including a deadline race, proving terminal
`:cancelled` and no retry.

- [ ] **Step 2: Run the engine suite and verify RED**

Expected: fail until timeout errors travel through the existing exception
retry branch correctly.

- [ ] **Step 3: Make the smallest retry integration correction**

Preserve the timeout error category and ensure each retry gets a fresh attempt
controller and full timeout duration. Ensure explicit `:retryable false` takes
precedence over message-based timeout heuristics.

- [ ] **Step 4: Run the engine suite and verify GREEN**

Run the focused engine suite. Expected: zero failures.

## Chunk 2: Shell-correct, killable ToolHandler

### Task 3: Preserve shell command semantics

**Files:**
- Modify: `src/attractor/handlers.lg`
- Modify: `src/attractor/engine.lg`
- Test: `test/attractor/handlers_test.lg`
- Test: `test/attractor/engine_test.lg`

- [ ] **Step 1: Write a failing ToolHandler shell-semantics test**

Use a unique temporary working directory and a command containing quoted
spaces and a pipeline. Assert the output reflects normal shell evaluation.

- [ ] **Step 2: Run the handlers suite and verify RED**

Run: `env LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/handlers_test.lg`

Expected: fail because whitespace splitting passes quote and pipe tokens as
literal arguments.

- [ ] **Step 3: Delegate ToolHandler to LocalExecutionEnvironment**

Require `attractor.execution`. For explicit timeouts, create a fresh local
environment and a cancellation watcher that invokes `:cleanup`, then join both
before returning. For unset timeouts, use the platform shell without imposing
the coding-agent command default. Map portable result fields into an Outcome.

- [ ] **Step 4: Run the handlers suite and verify GREEN**

Run the focused handlers suite. Expected: zero failures.

### Task 4: Enforce and classify ToolHandler timeout

**Files:**
- Modify: `test/attractor/handlers_test.lg`
- Modify: `test/attractor/engine_test.lg`
- Modify: `src/attractor/handlers.lg`
- Modify: `src/attractor/engine.lg`

- [ ] **Step 1: Write a failing process timeout test**

Run a command that emits partial output and sleeps beyond `timeout="50ms"`.
Assert elapsed time is bounded, the outcome is retryable/timeout-classified,
and partial output is retained both directly and through
`engine/execute-with-retry`. Use no recursive cleanup command.

- [ ] **Step 2: Run the handlers suite and verify RED**

Expected: fail until node timeout is forwarded and timed-out results are
classified correctly.

- [ ] **Step 3: Forward timeout and map timeout/cancellation outcomes**

Pass the parsed timeout milliseconds to `:exec_command`. Throw a retryable
`:timeout_error` for `:timed_out`, return `:cancelled` for environment
cancellation, and preserve stdout/stderr in context updates.

- [ ] **Step 4: Run the handlers suite and verify GREEN**

Run the focused handlers suite. Expected: zero failures.

## Chunk 3: Agent-backed codergen cancellation

### Task 5: Abort timed-out agent sessions

**Files:**
- Modify: `src/attractor/agent.lg`
- Test: `test/attractor/agent_test.lg`

- [ ] **Step 1: Write failing cancellation tests**

Create an agent backend with a blocked completion function and a node whose
`:cancelled?` predicate can be triggered. Assert the active provider operation
is aborted, the session closes, and a full-fidelity cache entry is removed.

- [ ] **Step 2: Run the focused agent suite and verify RED**

Run: `env LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/agent_test.lg`

Expected: fail because the backend currently blocks in `run-agent-turn!` and
never observes node cancellation.

- [ ] **Step 3: Add cancellable agent-turn execution**

Run the turn in a future when the node supplies `:cancelled?`; poll completion
at a short bounded interval, call `abort-session!` exactly once when signaled,
await shutdown, and throw a cancellation error. Reuse the existing error path
to evict full-fidelity sessions.

- [ ] **Step 4: Run the agent suite and verify GREEN**

Run the focused agent suite. Expected: zero failures.

### Task 6: Make parallel and manager handlers cooperative

**Files:**
- Modify: `src/attractor/handlers.lg`
- Modify: `src/attractor/engine.lg`
- Test: `test/attractor/handlers_test.lg`
- Test: `test/attractor/engine_test.lg`

- [ ] **Step 1: Write failing tests for parallel scheduling cancellation, active-branch predicate propagation and join, and manager child stop/join**
- [ ] **Step 2: Run handlers tests and verify RED**
- [ ] **Step 3: Pass the combined predicate through the engine branch callback, stop scheduling after cancellation, and join active branches and manager children**
- [ ] **Step 4: Run handlers tests and verify GREEN**

## Chunk 4: Integration, review, and release evidence

### Task 7: Verify inherited timeout through a real pipeline

**Files:**
- Modify: `test/attractor/parity_test.lg`

- [ ] **Step 1: Write a failing pipeline-level regression**

Parse a graph with an inherited node timeout and a custom cooperative handler.
Assert the pipeline fails with the timed-out node recorded and does not advance
to its success edge.

- [ ] **Step 2: Run parity tests and verify RED, then GREEN after integration**

Run: `env LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/parity_test.lg`

- [ ] **Step 3: Run complete verification**

Run sequentially:

```text
env LGX_LG=/Users/ndn/development/let-go/lg lgx test
env LGX_LG=/Users/ndn/development/let-go/lg lgx build
git diff --check
```

Expected: all tests pass, AOT binary builds, and diff check is empty.

- [ ] **Step 4: Request correctness review**

Ask a reviewer to compare the implementation and tests against
`specs/attractor-spec.md` timeout and ToolHandler requirements. Resolve all
Critical and Important findings and repeat full verification.

- [ ] **Step 5: Commit and push**

Commit the implementation as `feat(engine): enforce node timeouts`, push
`main`, and verify local HEAD equals `refs/heads/main` on origin.

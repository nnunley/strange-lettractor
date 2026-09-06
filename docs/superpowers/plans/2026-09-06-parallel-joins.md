# Parallel Joins Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development. Steps use checkbox syntax for tracking.

**Goal:** Make bounded parallel execution satisfy first_success promptly while joining every launched worker before return.

**Architecture:** Replace the parallel handler's pmap batches with an invocation-local bounded active set owned by a native let-go scope. Workers publish tagged result/error completion records; the coordinator stops launch on success, cancellation, or error, closes the scope with an indefinite drain, and collects all launched workers. Preserve existing factory arities, engine wiring, result order, and wait_all behavior.

**Tech Stack:** let-go 1.12.2+ via `/Users/ndn/development/let-go/lg`, lgx, futures/promises/atoms, EDN, existing pipeline engine.

Design: [parallel join contract](../specs/2026-09-06-parallel-join-design.md).
Worktree: `/Users/ndn/development/attractor/.worktrees/iter-0006-interactive-concurrency`.
Baseline: main `38e9c9e`, independently rerun in this worktree: 473 tests / 3370 assertions / zero failures. Separate reader compatibility remains 5 failed assertions; this work neither fixes nor hides them.

## Chunk 1: Parallel scheduling and direct contracts

### Task 1: Completion-driven coordinator

Files: modify `src/attractor/handlers.lg` only around the parallel handler; create `test/attractor/parallel_join_contract_test.lg`. Keep helpers private and cohesive. Do not restructure unrelated handlers.

- [x] Write a bounded self-unwinding first-success regression. Graph edges are slow, winner, queued in that order; max_parallel is 2. Slow announces entry, waits for branch cancellation, announces observation, and holds cleanup. Winner waits for slow entry before returning SUCCESS. Assert cancellation is observed before releasing slow, handler stays pending until release, queued never starts, and final ordered results are slow/winner with overall SUCCESS. Every barrier wait is bounded, and finally releases all blockers even on test failure.
- [x] Run `env LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/parallel_join_contract_test.lg`; require observed assertion failures against the current implementation, not just syntax/helper errors. Record RED counts.
- [x] Implement the invocation-local coordinator. Assign each edge its original index; track pending edges, launched futures, active completions, local-stop atom, and first primary exception. Workers wrap callback execution in try/catch and return a tagged record such as `{:index i :result result}` or `{:index i :error e}`; never leave a completion unpublished on an exception. Catch cloning and launch errors in the coordinator, request local stop, and join prior launches before rethrowing. Inspect ready records before replenishment, freeze scheduling once any exact SUCCESS is observed under first_success, and combine external cancellation with local stop only in branch predicates. Sleep briefly when no completion is ready. After stopping, join all launched futures, preserve original-order branch outcomes, and retain existing result/status/boundary assembly. Do not rely on future exceptions being rethrown by let-go deref.
- [x] Add bounded slot-replenishment evidence: while edge 0 is held, edge 1 finishes and edge 2 starts; an active counter proves max_parallel is never exceeded. Assert deterministic result order despite reverse completion.
- [x] Add direct cases for already-cancelled/no launch; cancellation winning success plus held cleanup; wait_all compatibility; all-fail and partial-success-only first_success exhaustion; max_parallel=1; target-ID versus exact-edge callback handoff; four-argument callbacks joined normally; no outgoing edges. Preserve existing numeric/unknown-policy behavior.
- [x] Add exception evidence: throwing worker stops queued launch and joins a held sibling; clone failure during replenishment cancels and joins existing work. Assert the original exception, no late writes, and finally-safe test release. Secondary cleanup exceptions must not replace the first coordinator-observed primary error.
- [x] Before changing the initial future-based patch, add native-supervision RED tests: loser blocked on native `<!` without predicate polling, descendant future cleanup on normal wait_all return, and independent sibling scope survival/caller restoration. Implement scope-open in the coordinator's own execution context before launch, a coordinator-owned close-once guard, and scope-close! with zero timeout on stop/error/normal exit. Set local cancellation before native scope cancellation. Do not close from a tracked child or use the default five-second escape. Native scopes handle lifetime and native blocking cancellation; explicit error records still handle propagation. Verify these tests using real native primitives, bounded external fixture escapes, and finally cleanup.
- [x] Run the new focused file and `env LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/handlers_test.lg` sequentially. Require nonzero test/assertion counts and zero failures for both. Inspect the diff and run `git diff --check`.
- [x] Commit only the scoped source/test files as `feat(parallel): coordinate early success and joined cancellation`. Require independent spec review, then code-quality review; fix and re-review findings before Task 2.


Task 1 evidence: runtime `4851b51`, throwable fix `84dffe9`; both review gates approved. Initial RED 8/64/11, native scope RED 14/142/3, throwable RED 15/163/4; final focused 15/163/0, handlers 20/60/0. Root full suite 488/3533/0, AOT exit 0, compiled real parallel workflow exit 0 with checked ordered branch outputs and completed checkpoint. Separate reader acceptance remains 5 failures. Public integration is still Task 2.

## Chunk 2: Public behavior and checkpoint

### Task 2: Public pipeline proof

Files: extend `test/attractor/parallel_join_contract_test.lg`; modify `src/attractor/engine.lg` only for demonstrated integration defects; update `docs/superpowers/iterations/{behavior-scenarios,behavior-corpus,progress}.md` and `requirements/attractor.md`.

- [x] Build a valid public DOT pipeline start -> fork -> two custom branch nodes -> fan-in -> exit. Register cooperative branch handlers and use real engine branch execution. Use barriers to prove loser observes cancellation, parent/fork completion is absent before cleanup release, and fan-in executes exactly once after cleanup. Verify winner/boundary routing, context isolation, deterministic stored parallel.results, and final checkpoint state.
- [x] Exercise external cancellation through this public seam and assert CANCELLED wins with no terminal event before branch cleanup. Verify an execution failure plus fidelity cleanup failure cannot silently replace an existing primary error; distinguish returned FAIL outcomes from thrown exceptions, preserving the current retry contract.
- [x] Run focused public evidence RED before any needed runtime fix; implement only the demonstrated gap. If existing behavior already passes, record this as evidence-only work, not a fabricated bugfix.
- [x] Run `env LGX_LG=/Users/ndn/development/let-go/lg lgx test` and `env LGX_LG=/Users/ndn/development/let-go/lg lgx build` sequentially. Expected full default suite: at least baseline 473 tests, zero failures; AOT exit 0. Run `/Users/ndn/development/let-go/lg -source-paths src:. compat/run_mapping.lg` separately and retain its failure count as unmet reader acceptance.
- [x] Obtain independent spec then quality review. Once proof is adequate, add exact `;; SCN-FIRST-SUCCESS COMPLETE` marker to the focused test file; update corpus command to require this marker and run that file. Correct ATTR-PAR-02 wording to success observation -> cancellation/join -> return; record component evidence without marking all ITER-0006 done. Other iteration stories remain required.
- [ ] Commit the public proof and scoped documentation. Push the iteration branch under standing user authorization and verify remote SHA. Preserve worktrees/private notes. Full ITER-0006 audit/integration waits for interviewer, fan-in, artifact, and handler-matrix components.

## Execution constraints

Only one lgx process may run per worktree: its generated runner is shared. Tests must use bounded waits and unconditional cleanup, never strand a worker when a regression is present. Use local let-go, not an installed alternative. Use apply_patch for edits, explicit git staging paths, and no worktree removal. Skill shared PAR templates are absent; independent scope reviewers used the available scope criteria and concrete code/spec inspection. Both approved the component; their exception-precedence caution is included in Task 2.

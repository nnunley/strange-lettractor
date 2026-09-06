# Completion-driven parallel joins

Approved direction: extend the existing handlers for true early first-success,
nonblocking console timeouts, LLM fan-in ranking, and recoverable artifacts.
This independently deliverable design covers the parallel-join component of
ITER-0006. Interviewers, fan-in, artifact discovery, and the handler matrix remain
required iteration work; completing this component does not complete ITER-0006.

## Source and current gap

StrongDM's [parallel handler](../../upstream/strongdm-attractor/attractor-spec.md#48-parallel-handler)
requires bounded isolated branches and join satisfaction as soon as one branch
succeeds. ATTR-PAR-02 additionally requires cancellation and joining of losers.
The current implementation uses batches of `pmap`, realizing every result before
checking the policy. Consequently it cannot cancel a blocked loser when a sibling
has already succeeded, and a slow batch member prevents replenishing a free slot.

## Chosen approach

Replace batch scheduling inside `make-parallel-handler*` with a bounded,
completion-driven coordinator. Preserve the public factory arities and engine's
existing branch-executor callback. Use let-go futures for active branches and
explicit completion records rather than waiting for futures in launch order.
Own all workers in one native let-go scope opened in the coordinator's execution
context before any worker launch. Scope inheritance owns registered descendant
async work, not just each callback's future. Keep changes local to the parallel
handler unless a public integration regression demonstrates an engine gap.
No general scheduler service or external dependency.

Upstream limitation: local `async/map` registers its worker in the process root
and escapes child-scope ownership, as independently reproduced in
[supervision compatibility](../../let-go-supervision-compatibility.md).
The scheduler uses scoped `future`/`go` primitives. The no-late-work contract is
proved for owned workers and registered descendants, not detached/root-owned
work launched by arbitrary custom callbacks. The upstream helper ownership gap
remains explicit; this component does not fix or claim it away.

Alternatives considered: retaining batches cannot meet early join; an unbounded
future per edge violates max_parallel. A fixed bounded active set is sufficient.

## Scheduling and lifecycle contract

- Launch outgoing edges in graph order, up to max_parallel (default four).
  Replenish available slots as completed work is observed, without batch barriers.
  Track edge occurrences by index, not target ID: duplicate target edges remain
  distinct launches. A completion record is not termination; join the worker
  before reusing its active slot.
- Each launched edge receives an independently cloned context, the existing
  branch log path, and the original edge or target ID according to pass-edge?.
  Preserve the four-argument executor compatibility path.
- Only exact SUCCESS satisfies first_success; PARTIAL_SUCCESS does not. Once a
  success is observed, freeze scheduling and signal cooperative cancellation to
  every active loser. Do not launch any further queued edges.
- Cancellation observed before launch prevents launch. Pipeline/node cancellation
  wins over successful branch results, stops scheduling, cancels active workers,
  and returns CANCELLED after all launched workers quiesce.
  Recheck parent cancellation after cleanup, including after first success.
- A branch cancellation predicate combines the invocation's cancellation source
  and local stop flag. A first-success local stop does not masquerade as parent
  cancellation when selecting the final handler status.
- On success/error/external cancellation, set the local stop flag first, then
  have the coordinator owner close its native scope exactly once with
  `scope-close! scope 0`. This cancels native blocking channel/sleep operations
  and drains the entire subtree indefinitely. Never close from a worker belonging
  to that scope (self-join). The default five-second with-scope warning/return
  behavior is insufficient for the no-late-work contract. Also close on normal
  completion and exceptional coordinator exit, preserving the primary error.
  Native scopes supervise lifetime, not exception transport: keep explicit
  worker error records. Scope closure must restore the caller's prior scope;
  independent sibling invocations must remain uncancelled.
- Join all launched workers, including their cleanup, before returning an outcome,
  rethrowing an execution exception, or allowing parent terminal events. No late
  mutation from a returned invocation. Never force-kill arbitrary user callbacks.
  Legacy four-argument or uncooperative callbacks cannot be interrupted: they are
  still joined, so prompt return is guaranteed only for cooperative executors.
- Exceptions in workers or context cloning stop further launch, request cleanup
  of launched workers, then propagate the original error. Every worker publishes
  completion in a finally-safe manner so errors cannot strand the coordinator.
- Polling, if used to observe the active set, must sleep briefly rather than spin.
  Do not introduce arbitrary production timeout limits on cleanup.

## Results and compatibility

Store completed launched branch outcomes in parallel.results in original edge
order, regardless of completion order. Include cancelled launched losers; omit
unlaunched edges. Preserve existing :id and :node_id association and boundary-node
selection (one distinct reported boundary yields :next_node_id).

Retain wait_all status behavior: FAIL results produce PARTIAL_SUCCESS; otherwise
SUCCESS, unless parent cancellation wins. Retain the existing no-outgoing-branches
FAIL and first_success exhaustion FAIL. Do not change unknown-policy or numeric
configuration behavior as incidental refactoring. No fan-in semantic changes here.

## Evidence

Use self-unwinding bounded test barriers, not scheduler-speed assertions:

1. Start a loser and winner concurrently; loser waits for cancellation, then holds
   cleanup. Winner succeeds only after loser has started. Assert cancellation was
   observed, handler remains pending until cleanup release, and queued work never
   starts. Release in finally and assert SUCCESS plus ordered results.
2. Hold the first edge while a later edge completes; a queued edge must start
   before the first edge is released, never exceeding max_parallel.
3. Parent cancellation wins a success race and joins cleanup; zero launches when
   already cancelled. Verify wait_all, all failures, partial-success-only, and
   max_parallel=1 behavior.
4. A throwing worker and clone failure cannot abandon launched workers. Assert
   original error propagation only after cleanup and no further scheduling.
5. Public pipeline execution proves actual branch cancellation reaches handlers,
   loser cleanup precedes fork/parent completion, fan-in is entered once, result
   order remains deterministic, and parent/sibling context isolation remains intact.
6. Run impacted handlers/engine/timeout/composition suites, full default suite,
   and local-compiler AOT. Report the separate failing reader compatibility gate
   alongside default-suite results, not as a pass or skip.
7. Native-supervision regressions: a losing callback blocked in `<!` (without
   polling the supplied predicate) is released by scope cancellation; cleanup
   remains joined. Callback-spawned descendants cannot outlive the invocation,
   including normal wait_all return. Independent sibling work survives another
   invocation's cancellation; caller scope is restored. The explicit zero drain
   argument must be exercised without replacing native scope cancellation by mocks.

Baseline main is 38e9c9e: default 473 tests / 3370 assertions / zero failures;
reader compatibility remains one test / five failed assertions. A fresh worktree
baseline must be checked before implementation.

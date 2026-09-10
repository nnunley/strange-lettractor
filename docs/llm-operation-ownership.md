# LLM operation ownership

Unified LLM §4.7 requires cooperative abort and streaming connection closure.
The adopted ULLM-CANCEL-01 contract additionally requires joined worker cleanup
before a terminal return and preservation of partial output. Before this change
`controlled-invoke` started a future and published abort/timeout without
cancelling or joining it, and the stream control monitor discarded its future.
Design: `superpowers/specs/2026-09-08-llm-operation-ownership-design.md`.

## Contract

- One persistent coordinator (`attractor.operation-owner`) per `generate` or
  high-level `stream` call. It belongs to the caller's scope and opens the owned
  child scope inside its own execution context; the lazy consumer's scope is
  never mutated and no scope is opened or closed per event.
- Demanded provider calls, lazy stream reads and tool rounds run as owned jobs.
  The child scope persists across successful reads, so a live socket is not
  cancelled between chunks.
- The coordinator polls control while busy and idle: external signal, total
  deadline, the stream step deadline and the current invocation deadline. Parent
  scope cancellation is observed with the local `scope-cancelled?` predicate.
- Terminal cause election is atomic (`compare-and-set!`); a local abort/timeout
  wins over the transport error it causes and over a concurrently ready result.
- Terminal acknowledgement (and every public terminal return) follows body
  closure and indefinite scope drainage. A failed attempt drains before its
  error is published, so a retry never overlaps its predecessor's resources.
- While an attempt drains, the combined abort signal reports aborted so
  cooperative descendants stop before they are joined. Callbacks that ignore the
  signal are joined, not abandoned: an explicit residual limitation.
- External `close` joins cleanup; close from an owned callback only requests it.
  The public stream `close` never throws (a consumer closing from a `finally`
  keeps its own error). Cleanup errors never mask a primary error; a successful
  `generate` surfaces them, while stream completion discards them because every
  event has already been delivered and there is nothing left to attach them to.
- Jobs run with the caller's dynamic bindings (`bound-fn*`, which needs the
  local scope-preserving runtime fix, nooga/let-go#832) so tool callbacks and
  custom clients behave as before the coordinator existed.
- A reply already published by a job is delivered even if a close request
  lands in the same tick; only unfinished work is dropped.
- Close-handle registrations are stamped with the attempt generation; a handle
  published late by a drained attempt cannot replace its successor's.
- Tool calls dispatch eagerly in windows of 32, preserving order and the old
  `pmap` concurrency bound.
- Option validation runs before the coordinator starts, so a rejected option
  cannot leak one.
- Public signatures, tool rounds, structured output, partial responses and error
  identity are unchanged. `execute-tool-calls` dispatches futures eagerly so
  tool workers inherit the owned scope (lazy `pmap` detached them, see below).

## Review

An independent read-only review ran through `bin/attractor claude` (Opus,
plan mode) against the integrated change and reported eleven findings. Accepted
and fixed with regression tests: public `close` throwing the terminal error;
`submit!` preferring a terminal over an already-published reply; caller bindings
not reaching jobs (which exposed runtime #832); unstamped close registrations;
unbounded tool fan-out; a busy wait in the caller's loop after its own scope was
cancelled; cleanup skipped at terminal after an attempt drain; a coordinator
leak when option validation throws. Rejected with evidence: the claim that an
unconsumed stream blocks its parent scope from quiescing (the coordinator drains
on parent cancellation, `unconsumed-stream-drains-when-parent-scope-closes`),
and the proposal to bound the drain with an `:operation-unjoined` error, which
contradicts the approved design's indefinite-join requirement and is recorded
below as a residual limitation instead.

## Evidence (2026-09-08, runtime `425d8461` on `bdd8268c`)

- Owner witnesses `test/attractor/operation_owner_test.lg`: 24 tests / 110
  assertions, including idle parent-scope cancellation without a control
  signal, reply-before-close ordering, caller bindings and terminal cleanup.
- Shared adapters `test/attractor/llm_cancellation_ownership_test.lg`: generate
  and stream × abort and per-step timeout (previously 8 failing assertions),
  unconsumed stream drained by parent scope close, silent close after abort,
  stale registration rejection, bounded tool dispatch and no coordinator leak
  on invalid options: 9 tests / 35 assertions.
- Native OpenAI loopback `test/probes/llm_ownership_http_check.lg` against the let-go
  fixture `test/fixtures/context_discovery_server.lg`: held headers, held SSE body with
  partial output preserved, held JSON body, each × abort/total/per-step; normal
  paced multi-chunk stream and tool continuation with every body closed exactly
  once and zero surviving workers. 3 tests / 67 assertions, run twice.
- Full suite 791 tests / 7291 assertions / 0 failures; focused bundle from
  outside the checkout 33 / 145 / 0; CLI build and `help` pass. let-go runtime:
  `go vet` and `pkg/rt`, `pkg/vm`, `pkg/api`, `test/e2e` pass, the full jank
  Clojure suite passes (243 cases) and the native-entry gate passes with the
  linked `clojure-test-suite`.

## Runtime dependencies and limits

- nooga/let-go#829: lazy-seq thunks realize under the root execution context.
  Work inside a thunk is not cancelled by closing the owned scope; cancellation
  reaches it only through registered body closers and the combined signal.
  Reproducer `test/probes/lazy_scope_isolation_check.lg` exits 1 until fixed.
- nooga/let-go#830: `scope-cancelled?` is local; `sleep` returns silently on
  cancellation, so without it an idle coordinator spins.
- nooga/let-go#831: streamed `http/serve` bodies are local; without them the
  held-body fixtures degrade to held headers. Handlers cannot observe client
  disconnect, so cleanup is witnessed client-side.
- A stream that is neither consumed to completion nor closed keeps its idle
  coordinator (5 ms control polling) until its parent scope closes or a
  configured deadline or abort fires. Consumers own `close` for early exits.
- Drainage is an indefinite join by design. A provider or tool that ignores
  both scope cancellation and the combined abort signal delays the public
  return until it finishes, rather than being abandoned; there is no
  `:operation-unjoined` error. The retry backoff wait in `controlled-sleep!`
  (pre-existing) still polls with `sleep` and can spin briefly if the caller's
  own scope is cancelled without an elected terminal reason.
- Not covered: adapter connect/request/stream-read timeout distinctions, the
  remaining status/drop/retry matrix, and server-observed disconnects.

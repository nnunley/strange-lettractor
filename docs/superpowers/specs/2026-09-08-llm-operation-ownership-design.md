# High-level LLM operation ownership

This is a correctness repair under the user's standing authorization for
transparent fixes, not a new public workflow API. Scope reviews A and B approved
the revised persistent-coordinator approach. Implementation is pending.

Upstream unified LLM §4.7 requires cooperative abort and streaming connection
closure. The adopted ULLM-CANCEL-01 contract additionally requires joined worker
cleanup before terminal return and preservation of partial output. Do not claim
these stronger guarantees from error classification alone.

## Evidence

At public checkpoint f86b5d5, the fixed-runtime sentinel suite passes 758 tests /
7146 assertions. New permanent ownership regression tests fail exactly eight
assertions across four cases: generate/stream opening, abort/per-step timeout.
Each gets the right error but observes unfinished provider finally cleanup and
live workers. Native HTTP scope cancellation itself is already fixed locally.

## Chosen architecture

Use one persistent coordinator future per high-level operation. It belongs to
the parent scope and opens its owned child scope inside its own execution
context, never in the lazy stream creator's caller context. Demanded provider
calls and lazy reads execute as tagged-result jobs under the child scope. The
scope persists between reads, so successful reads do not cancel the socket.

The coordinator polls operation control while busy and idle, replacing the
discarded monitor future. Terminal acknowledgement follows cancellation,
body-close attempts and scope drainage. Public terminal returns wait for that
acknowledgement. Terminal reason selection is atomic; a local abort/timeout
must not become a provider error merely because cancellation broke a read.

Explicit close from an external caller joins cleanup. Close from an owned
callback requests closure without waiting on itself; the outer public caller
still observes terminal acknowledgement only after that callback exits.
Owned callback recognition must include body closers and inherited descendants.

Each retry attempt owns its resource generation. It closes and joins before a
successor attempt starts; stale body registrations cannot replace a successor's
close handle. Cleanup errors cannot skip native drainage or mask a primary
failure. Noncooperative custom callbacks are an explicit residual limitation,
not permission to claim quiescence while work survives.

Rejected alternatives: per-read scopes cancel live streaming bodies; a persistent
scope opened in high-level-stream leaks dynamic scope into unrelated caller work;
merely joining the existing future cannot interrupt native I/O or prevent self-join.

## Evidence gates

Test abort/total/per-step timeout while connecting, buffering bodies, opening
streams, reading chunks and idle between reads. Include normal delayed lazy
consumption, cross-future consumption, sibling isolation, unconsumed streams,
explicit and reentrant close, late registration, retry attempt cleanup, throwing
closers, delayed finally blocks, terminal races, partial output and no later
tools/frames/retries. Real socket evidence supplements deterministic wrapper
tests; no new Go fixture or JVM API is introduced.

Full adapter connect/request/stream-read timeout distinctions and the remaining
status/drop/retry matrix remain open in ITER-0010. Completing this component does
not close ULLM-CANCEL-01, ULLM-ERROR-01 or the full Attractor goal by itself.

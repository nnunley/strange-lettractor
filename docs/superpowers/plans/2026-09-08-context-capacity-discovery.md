# Context Capacity Discovery Implementation Plan

> Workers: use subagent-driven-development and test-driven-development. Main
> owns integration and verification; use the existing Attractor Claude connector
> for bounded worker/review tasks. Batch the final checkpoint, not each tiny edit.

**Goal:** refresh deployed model context capacity before every agent model call.

**Architecture:** an optional adapter discovery callback returns normalized EDN
metadata. A separate let-go namespace owns bounded native HTTP discovery for
recognized llama.cpp endpoints. Session publication is guarded by turn ownership.

**Tech stack:** let-go, native supervisor scopes, HTTP/JSON boundary, EDN state,
clojure.test; no new Go fixture or product implementation.

## Chunk 1: Native discovery and adapter capability

Files: `src/attractor/context_discovery.lg`, `src/attractor/llm.lg`,
`test/attractor/context_discovery_test.lg`, `dev/context_discovery_tests.lg`.

- [ ] Add tests through existing `llm/make-adapter` proving the optional
  `:discover_context` callback is preserved. Demonstrate failure before editing.
- [ ] Add `context-discovery/discover!` taking resolved `:base_url`, `:model`,
  `:headers`, `:timeout_ms`, and optional `:aborted?` callback. Recognize llama.cpp
  from matching `/models` entry ownership, then inspect same-origin `/props`.
  Reject mismatched model, nonpositive/noninteger n_ctx, unsupported endpoint,
  HTTP error, invalid JSON, and expired/canceled operations with typed outcomes.
- [ ] A native var metadata capability marks scope-aware HTTP. Check it before
  starting native requests; older runtimes must report an unavailable prerequisite.
- [ ] Native worker opens a child scope; completion/error, deadline, and abort all
  cancel/join/restore scope before returning. Never use native timeout map options.
- [ ] Preserve deployment path prefixes; strip only terminal `/v1` for props.
  Do not autoload models, cache across endpoints/models, or persist credentials.
- [ ] Test distinct endpoints/models, n_ctx independent of training/slot counts,
  default 1000 ms budget, and redaction of credentials and raw props. Never pass
  unsupported native `:abort_signal` options to enforce cancellation.
- [ ] Expose `llm/client-discover-context` and `llm/discover-context` using actual
  adapter routing/configuration. Only native custom OpenAI-compatible endpoints
  probe automatically; mock/injected generation remains offline by default.

## Chunk 2: Session refresh

Files: `src/attractor/agent.lg`, `test/attractor/context_capacity_test.lg`.

- [ ] RED: capture real session behavior using a custom adapter that returns two
  capacities across two calls. Verify live values and warning thresholds change.
- [ ] RED: explicit `:context_window_size` override wins without remote probes;
  invalid override/time budget fails configuration, not midway through a turn.
- [ ] Refresh after admission and before every actual model request, not after
  turn-limit exit. Guard publication by current turn owner and stopped state.
- [ ] Store `:context_capacity` metadata with source/status/model/observation time;
  update the profile window consumed by existing approximate warnings. Reset the
  warning latch on capacity/source change. No automatic history compaction.
- [ ] Failure replaces stale discovery with labeled profile fallback; warn on
  unavailable discovery. `:require_context_discovery` makes failure explicit.
- [ ] Test decreases between tool rounds, stale-success invalidation, canceled
  predecessors, adapter/provider identity, and offline custom completion behavior.

## Chunk 3: Native/bundle/live verification and publication

- [ ] Write let-go loopback fixture/checker under `dev/` for metadata refresh,
  held headers/body, timeout/abort cleanup and same-runtime capability checks.
  Keep server/helper process lifetime owned and bounded.
- [ ] Run focused native tests with the fixed local runtime, then bundle the
  runner using `lg -source-paths src:test -b TEMP/runner dev/context_discovery_tests.lg`
  and run it outside the checkout.
- [ ] Read live ndn.local capacity through the actual discovery implementation;
  do not hardcode the observed number or modify server configuration.
- [ ] Run `LGX_LG=FIXED_RUNTIME lgx test`, build/help, and bounded independent
  spec and correctness review through the framework connector.
- [ ] Update progress/evidence documents, commit scoped Attractor files, push
  public main/console and verify remote refs. Keep private notes untracked.

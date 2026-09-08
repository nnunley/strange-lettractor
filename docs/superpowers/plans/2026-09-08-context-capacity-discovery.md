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

## In-progress review checkpoint (2026-09-08)

Implementation and verification are complete; publication is next. Claude spec review through
`bin/attractor claude` completed (session
`a0ada828-52c0-4478-8df2-c7b02f36fcc3`). Remaining findings:

- Resolved: safe endpoint identity and original observation time retained.
- Resolved: one bounded operation at each public entrypoint; native `probe!` is
  the internal caller-owned operation. Custom adapter calls remain bounded.
- Resolved: distinct physical endpoint/model isolation and a controlled
  predecessor/successor publication race are mechanically tested.
- Resolved: held-body streaming and buffered discovery both cancel and join.
  The response producer is let-go; OpenBSD-compatible `nc` only supplies a
  listening socket (currently absent from native `net`). The pipeline is owned
  by Attractor's execution environment and joined in cleanup.
- Resolved: adapter budget precedence, overflow-safe warning arithmetic, and
  router model selection using `io/encode :url` plus `autoload=false`.
- Final narrow correctness review completed; its sole finding was rejected
  against constructor validation and passing tests (see adjudication below).
- Pending: publication verification.

Current focused evidence: native/bundled session tests 16/76/0 and transport
tests 14/35/0; loopback 3/39/0. The final full suite passed 758/7146/0;
standalone CLI build and `help` passed. Live read-only discovery still returns 131072
through the updated router-safe path. The first broad correctness review timed
out without a verdict; the narrower connector review completed. No review success
is inferred from timeout or tool activity.

### Final review adjudication

Summary judgment: no confirmed blocker in the reviewed discovery/publication scope.
Scope reconstructed: native probe and scope wrapper, public llm entrypoints,
session publication and warning arithmetic; adjacent constructor inspected by main.
Finding 1 (invalid override silently demoted): **Rejected**. `make-session`
validates `:context_window_size` before environment initialization (agent.lg:408),
and `invalid-explicit-configuration-fails-before-session-initialization` proves
configuration errors and no initialization side effect. The review's limited
read window omitted this prerequisite. Finding 2 reported no other blocker.
Missed-findings pass: one focused pass over constructor, publication, URL routing
and scope cleanup found no additional high-confidence defect.
Review quality note: narrowing after timeout excluded relevant constructor context.
Residual uncertainty: native fixes remain local; callback cooperation is required;
this is not a full Attractor conformance audit.
Response draft: accepted the clean findings on routing, scope count, redaction and
owner guards; questioned finding 1 with constructor/test evidence; no unresolved
clarification or newly added concern.

The review's tool-round coverage finding is now addressed by a passing session
test. A separate regression proved copied session profiles could promote a prior
live window into the advisory fallback; the profile now preserves its original
fallback. Focused session tests pass natively and bundled outside the checkout:
10 tests, 49 assertions, zero failures/errors. Transport tests previously passed
13 tests/33 assertions and native HTTP checks 1 test/30 assertions. The first
full-suite run passed 749 tests/7112 assertions before the final two session tests.
Live discovery returned 131072 for the then-running ndn.local deployment; this
is an observation, not a constant or configuration change.

Runtime prerequisites remain local in the isolated `let-go-http-cancellation`
workspace: scope-aware native HTTP (#816), capability metadata, and the empty
headers-map fix reported as https://github.com/nooga/let-go/issues/828. Latest
runtime rt/vm/api package tests and vet pass; these fixes are not yet upstream.

## Chunk 1: Native discovery and adapter capability

Files: `src/attractor/context_discovery.lg`, `src/attractor/llm.lg`,
`test/attractor/context_discovery_test.lg`, `dev/context_discovery_tests.lg`.

- [x] Add tests through existing `llm/make-adapter` proving the optional
  `:discover_context` callback is preserved. Demonstrate failure before editing.
- [x] Add `context-discovery/discover!` taking resolved `:base_url`, `:model`,
  `:headers`, `:timeout_ms`, and optional `:aborted?` callback. Recognize llama.cpp
  from matching `/models` entry ownership, then inspect same-origin `/props`.
  Reject mismatched model, nonpositive/noninteger n_ctx, unsupported endpoint,
  HTTP error, invalid JSON, and expired/canceled operations with typed outcomes.
- [x] A native var metadata capability marks scope-aware HTTP. Check it before
  starting native requests; older runtimes must report an unavailable prerequisite.
- [x] Native worker opens a child scope; completion/error, deadline, and abort all
  cancel/join/restore scope before returning. Never use native timeout map options.
- [x] Preserve deployment path prefixes; strip only terminal `/v1` for props.
  Do not autoload models, cache across endpoints/models, or persist credentials.
- [x] Test distinct endpoints/models, n_ctx independent of training/slot counts,
  default 1000 ms budget, and redaction of credentials and raw props. Never pass
  unsupported native `:abort_signal` options to enforce cancellation.
- [x] Expose `llm/client-discover-context` and `llm/discover-context` using actual
  adapter routing/configuration. Only native custom OpenAI-compatible endpoints
  probe automatically; mock/injected generation remains offline by default.

## Chunk 2: Session refresh

Files: `src/attractor/agent.lg`, `test/attractor/context_capacity_test.lg`.

- [x] RED: capture real session behavior using a custom adapter that returns two
  capacities across two calls. Verify live values and warning thresholds change.
- [x] RED: explicit `:context_window_size` override wins without remote probes;
  invalid override/time budget fails configuration, not midway through a turn.
- [x] Refresh after admission and before every actual model request, not after
  turn-limit exit. Guard publication by current turn owner and stopped state.
- [x] Store `:context_capacity` metadata with source/status/model/observation time;
  update the profile window consumed by existing approximate warnings. Reset the
  warning latch on capacity/source change. No automatic history compaction.
- [x] Failure replaces stale discovery with labeled profile fallback; warn on
  unavailable discovery. `:require_context_discovery` makes failure explicit.
- [x] Test decreases between tool rounds, stale-success invalidation, canceled
  predecessors, adapter/provider identity, and offline custom completion behavior.

## Chunk 3: Native/bundle/live verification and publication

- [x] Write let-go loopback fixture/checker under `dev/` for metadata refresh,
  held headers/body, timeout/abort cleanup and same-runtime capability checks.
  Keep server/helper process lifetime owned and bounded.
- [x] Run focused native tests with the fixed local runtime, then bundle the
  runner using `lg -source-paths src:test -b TEMP/runner dev/context_discovery_tests.lg`
  and run it outside the checkout.
- [x] Read live ndn.local capacity through the actual discovery implementation;
  do not hardcode the observed number or modify server configuration.
- [x] Run `LGX_LG=FIXED_RUNTIME lgx test`, build/help, and bounded independent
  spec and correctness review through the framework connector.
- [ ] Update progress/evidence documents, commit scoped Attractor files, push
  public main/console and verify remote refs. Keep private notes untracked.

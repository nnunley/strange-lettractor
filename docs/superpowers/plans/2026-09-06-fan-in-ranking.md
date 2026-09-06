# Fan-In Ranking Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development. Steps use checkbox syntax for tracking.

**Goal:** Implement StrongDM §4.9 prompted selection and deterministic heuristic fan-in through real public entrypoints.

**Architecture:** A focused `attractor.fan-in` selector/handler uses an injected ranker; `attractor.fan-in-llm` adapts the unified client. The registry retains existing arities and gains an options arity. CLI run/resume supplies model overrides and no-network mock behavior. Runtime closures never enter captures.

**Tech Stack:** Local let-go `/Users/ndn/development/let-go/lg`, lgx, existing unified LLM client and pipeline, EDN persistence.

Approved design: [fan-in ranking](../specs/2026-09-06-fan-in-ranking-design.md).
Worktree: `/Users/ndn/development/attractor/.worktrees/iter-0006-interactive-concurrency`.
Baseline checkpoint: `6786da5`; last verified full suite 491/3585/0, separate reader acceptance 1 test/5 failures. Refresh baseline before runtime edits.

Fresh root baseline at `6786da5`: 491 tests / 3585 assertions / zero failures,
exit 0. All three plan chunks passed independent review. User approval is recorded
in the design; Task 1 is executing in the existing isolated iteration worktree.

## Chunk 1: Selection semantics

### Task 1: Focused handler and deterministic/injected selection

Files: create `src/attractor/fan_in.lg`, `test/attractor/fan_in_contract_test.lg`; replace only the old `handle-fan-in` body in `src/attractor/handlers.lg` with delegation and add its require. No LLM/CLI wiring yet.

- [ ] Add a native-readable regression against existing `handlers/handle-fan-in`: SUCCESS records a/score1 and z/score9 must choose z. A lone RETRY must be selectable. Run `env LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/fan_in_contract_test.lg` and record actual failing assertions, not a namespace error.
- [ ] Create `(make-handler ranker)` returning `[node ctx graph logs-root]`. Handler reads `parallel.results`, checks cancellation, enumerates original indices, filters to SUCCESS/PARTIAL_SUCCESS/RETRY, chooses heuristic for blank prompts or calls ranker once with `{:node node :prompt prompt :candidates [{:index i :candidate original-record} ...] :cancelled? predicate}`. The ranker returns an original integer index. Missing ranker on a prompt throws non-retryable configuration error until Task 2 supplies the default adapter. Preserve FAIL reasons for empty/all-ineligible inputs, existing best_id/best_outcome string values, notes, and id/node_id fallback.
- [ ] Heuristic key is `[status-rank (- score) string-id original-index]`; missing score is zero, present nonnumeric score throws non-retryable configuration error. Validate only eligible scores and only on heuristic path. Reject NaN/infinite scores if the runtime represents them: no nondeterministic ordering. Ranker-selected index must belong to eligible indices, and cancellation after invocation returns CANCELLED without winner updates. Never mutate the context or candidate records. Let thrown ranker errors propagate unchanged for existing retry classification.
- [ ] Extend tests: all status ranks, descending score, ID and original-occurrence ties, duplicate target IDs, absent scores, invalid score, empty/all-ineligible, blank/nonblank prompts, complete request data and one invocation, invalid index type/range/ineligible membership, exact error identity, pre/post cancellation, and unchanged parent context. Use bounded fixtures and finally release any barriers.
- [ ] Run focused tests and `lgx test test/attractor/handlers_test.lg` sequentially with local LGX_LG. Run `git diff --check`; commit scoped source/tests. Obtain independent spec review then quality review; fix/re-review before Task 2. Do not add completion markers yet.

## Chunk 2: Unified LLM and entrypoint wiring

### Task 2: Adapter and runtime configuration

Files: create `src/attractor/fan_in_llm.lg`, `test/attractor/fan_in_llm_contract_test.lg`; modify `src/attractor/handlers.lg`, `src/attractor/cli.lg`; extend appropriate CLI contract tests. Inspect `src/attractor/server.lg` only change if the new default registry needs explicit wiring.

- [ ] Write failing adapter tests with a real `llm/make-client` plus in-memory provider adapter; inspect actual existing client test helpers before using them. Assert generated request model/provider/reasoning/schema, instruction/data separation, one requested selection, and returned original index. Test node-over-default resolution and CLI overrides separately.
- [ ] Implement `(make-ranker options)` invoking `llm/generate-object`. Schema is an object with required integer `candidate_index` and no additional properties. Use a system instruction for selection and a separate user message containing evaluation prompt and EDN candidate envelopes as data. Resolve configured model via existing `llm/parse-model-spec`, pass injected client and cancellation, and never invent a model or mock answer. Extract string-keyed output; translate only `:no-object-generated` into non-retryable configuration error with cause. Selector checks eligible-index membership. Preserve provider error and cancellation identities.
- [ ] Test malformed JSON, schema-invalid object, out-of-range and ineligible index, provider exception, cancellation, missing model, and no tools/tool loop. Confirm output changes winner relative to the heuristic.
- [ ] Extend registry factory with `[interviewer codergen-backend options]`; `:fan-in-ranker` overrides the default `(make-ranker (:fan-in-llm-options options))`. Existing 0/2 arities remain compatible. `handlers/handle-fan-in` delegates to the real default ranker; custom registered handlers remain authoritative. Keep dependencies acyclic.
- [ ] CLI run and resume construct ranker options from `--model`/`--provider` with override-before-node precedence. Explicit `--mock` injects a ranker that throws a descriptive non-retryable configuration error; neither credentials nor node settings can bypass it. Test both entrypoints without live network. Server/default library uses node settings through the default factory, with no model invented from credentials.
- [ ] Run both focused files, impacted CLI/handler tests, full default suite and AOT sequentially. Inspect diff, commit scoped files; independent spec then quality review before Task 3.

## Chunk 3: Public proof and publication

### Task 3: Lifecycle, recovery, and cancellation evidence

Files: extend `test/attractor/fan_in_contract_test.lg` or create `test/attractor/fan_in_pipeline_contract_test.lg`; update `docs/superpowers/iterations/{requirements/attractor,behavior-scenarios,behavior-corpus,progress}.md` and this plan.

- [ ] Public DOT fixture: start -> wait_all fork -> two custom branches -> prompted fan-in -> exit. Inject a ranker via registry options; select a winner opposite the heuristic and verify prompt/candidate data, ordered parallel results, best_id/best_outcome, terminal outcome and saved checkpoint. Empty-prompt variant must not invoke ranker. Use real engine branch execution, not a fake parallel executor.
- [ ] Prove registry cloning and caller registry immutability; run the configured registry across independent runs and a nested child or manager child. Prove captured pinned resume with the registry re-injected preserves selection without serializing closures. Copy the interrupted run/capture to a separate temporary root before resuming; ordinary resume may update that copy's checkpoint. Mutate current DOT to ensure resumed prompt is captured, not current. Compare all original interrupted checkpoint/artifact bytes unchanged.
- [ ] Hold ranker cleanup with bounded promises in two separate public cases: external cancellation and node-attempt timeout. Prove no parent terminal event/return before release and no winner updates after either cancellation source. Use native scoped primitives and finally cleanup; do not rely on detached async/map ownership.
- [ ] Run full `env LGX_LG=/Users/ndn/development/let-go/lg lgx test` and `lgx build` sequentially. Run `/Users/ndn/development/let-go/lg -source-paths src:. compat/run_mapping.lg` separately, retaining failures as unmet reader acceptance. Run a fresh compiled heuristic workflow and inspect its persisted winner; offline prompted adapter evidence is not live-provider parity.
- [ ] Independent spec then quality review of public proof and the complete component. Only after approval add exact `;; SCN-FANIN-RANKING COMPLETE` marker, marker-gated focused corpus command, and scoped ATTR-FANIN-01 evidence. Keep interviewer/artifact/handler-matrix work pending; do not mark ITER-0006 done.
- [ ] Commit/push explicit scoped files under standing approval; verify remote SHA. Preserve all worktrees and private `docs/notes.md`. Record upstream workaround references without claiming the let-go bugs fixed.

## Execution constraints

API inspection: generation cancellation is `:abort_signal {:aborted? predicate}`,
not `:cancelled?`. `generate-object` accepts `(model prompt schema options)`;
for separated messages pass nil prompt and `:messages` in options. Model parsing
gives a provider-qualified model prefix precedence over the explicit provider,
matching the existing CLI helper; do not silently alter that shared convention.

One lgx process per worktree: it writes a shared generated runner. Use apply_patch,
explicit staging (new docs require git add -f), and local compiler. Never stage
private notes or modify the dirty local let-go checkout. No repeated design gate:
the user explicitly approved this contract. Reviews are task gates, not new user
approval requirements unless scope or the approved contract materially changes.

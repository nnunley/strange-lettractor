# Original specification closure

For current native-provider and OpenRouter conformance results, report IDs,
and gateway provenance, see the [canonical provider evidence](../../provider-model-audits.md#live-coding-conformance-follow-up--2026-09-27).

2026-09-27 live follow-up: `lgx live-coding-conformance` now combines all
fifteen parity rows and the implemented seven-step same-session smoke, with
explicit provider/check/row scope and native-origin validation. Anthropic has
15/15 parity coverage across an initial 13-row pass and a targeted two-row rerun
after clarifying exact-output prompts (assertions unchanged). Gemini also covers
15/15 across its repaired full run and targeted loop-warning rerun. Strengthened
Anthropic smoke passes five steps before quota-exceeded in the subagent step;
timeout remains unrun. Gemini strengthened smoke passes all seven steps. Initial
weaker smoke evidence is excluded. First-party OpenAI is wire verified, direct live not run, and
explicitly accepted by the user for publication without a push blocker. See
[current provider
evidence](../../provider-model-audits.md#live-coding-conformance-follow-up--2026-09-27).
The current named audit includes these follow-ups. The earlier full-suite count
below remains dated repair evidence, not final publication verification.

2026-09-27 coding-loop repair: [CAL-AUDIT-01–04](../../coding-loop-audit-2026-09-27.md)
are repaired with regular regressions for local child cancellation, steering
retention, shell errors and supplied-environment timeout caps. The named audit
passes 261 tests / 2529 assertions with zero failures/errors. Earlier repair full suite passed
1566 tests / 14159 assertions with zero failures. Custom environments need
optional `:fork_scope` for independent child cancellation; full live coding parity and the same-session
smoke remain separate evidence obligations.

Objective: finish the three specifications in `specs/`. Existing story statuses
are historical evidence, not a completion assertion. The 2026-09-23 review was
progress: it produced reproducible failures that determine the next repairs.

Implementation staffing (user-directed 2026-09-23): delegate bounded repairs to
`gpt-6-luna`; use `gpt-6-sol` for multi-file implementation requiring judgment.
The primary agent coordinates, integrates and verifies. Prefer targeted task
briefs over full-history forks. The specification objective is unchanged.

The closure audit must cover every normative prose section, definition-of-done
checkbox, provider parity cell, and integration smoke journey. Separate module
publication, JVM Clojure portability, and application extensions are not added
to the original specifications' completion criteria.

## Current repair sequence

2026-09-24 checkpoint: ITER-0020 shared agent journeys and Gemini 2.5 reasoning
serialization are reviewed and integrated. The exact live runner is exercised
through all three native scripted protocols, including valid-path and causal
failure controls. Final suite: 1498 tests / 13585 assertions / zero failures;
compiled CLI gates and example validation pass. ITER-0021 provider journeys plus
the Gemini/Anthropic signed-history repair have paired spec/quality approval;
root focused proof passes62/673/0 and final full-suite integration passes
1526/13863/0. The paired audits' final verification condition is satisfied.
After these, the user has promoted the approved offline catalog EDN extraction
ahead of shared-session smoke. User-funded Gemini and Anthropic basic requests
now return HTTP 200. Eight native rows pass on each low-cost model; three rows
also pass on each catalog default. Gemini signatures and a Fable high-reasoning
agent's signed thinking replay succeed natively. Complete matrices and native429
evidence remain unproved; see `docs/provider-model-audits.md`.

1. **ULLM-STRUCTURED-01, annotation repair verified; dialect closure in step 6:** implement unevaluated object/array
   locations using immutable, instance-local annotation results. Successful
   in-place applicators and references contribute coverage; failed branches,
   `not`, and child-instance validation do not. Preserve the public validator's
   `[valid? reason]` interface and enforce results in both structured APIs.
   Independent scope reviews agree this implements §§4.5–4.6 and §8.4.
2. **Original-scope audit, targeted findings recorded:** independent runtime/agent and LLM
   audits reconcile implementation and evidence with current source. Findings
   live beside this file in `2026-09-23-*-audit.md`.
3. **Implemented and integrated:** preserve completed false/null
   structured streams; make profile editing work through standard execution
   environments, with explicit raw-file versus tool-display contracts.
   **Reference repair verified at focused seam:** resource `$id` indexing,
   RFC 3986 relative resolution, explicit registry/retrieval URI, dynamic
   anchors, and annotation propagation now pass all 323 vendored official
   draft2020-12 ref/dynamicRef/unevaluated cases without exclusions. Resolution
   errors cannot turn into validation successes through boolean applicators.
   Paired review also found and verified the `$id`-named container fix.
4. **Implemented and integrated:** runtime SKIPPED outcomes
   preserve prior recorded outcomes while advancing traversal. Saved transitions
   carry routing through resume without storing skipped outcomes. Focused and
   impacted verification passes 208 tests / 1506 assertions; spec review is clean
   after direct codergen and checkpoint validation repairs. Paired code-quality
   review is clean. Full lgx suite passes 1453 tests / 11844 assertions / zero
   failures. See `skipped-outcome-plan.md`.
5. **Preparation repair implemented and reviewed:** DOT BareValue accepts
   hyphens while identifiers/attribute keys remain strict; stylesheets reject
   invalid reasoning values without partial application; named lint objects
   run alongside functions and Vars. Fresh public focused verification passes
   40 tests / 327 assertions / zero failures; paired spec and quality reviews
   approve. Full lgx 0.3.2 suite passes 1460 tests / 11894 assertions / zero
   failures; fresh standalone CLI validates the example. See
   `preparation-contract-plan.md`.
6. **Schema dialect repair implemented and integrated:** explicit 2020-12 and
   registered custom dialects select active vocabularies per resource. Invalid
   schemas fail preflight, including unused branches; both structured APIs
   enforce the result. All 1301 mandatory official cases pass, alongside 20
   focused tests / 88 assertions and six standalone compiled probes. Paired
   spec and quality reviews approve. Final lgx 0.3.2 suite passes 1481 tests /
   13376 assertions / zero failures. See `schema-dialect-plan.md` and the
   [documented support contract](../../schema-validation.md).
7. **Catalog freshness implemented and integrated:** gpt-6-luna added current
   Opus 5.5/Sol/Luna entries, corrected sourced metadata and preserved existing
   aliases/defaults. Root focused checks pass 137/822/0; paired spec and quality
   reviewers approve. Final full suite passes 1485 tests / 13406 assertions /
   zero failures, and a fresh standalone CLI validates the example. See
   `catalog-refresh-plan.md`.
8. **Implemented and integrated:** ITER-0020 adds the five missing agent rows;
   ITER-0021 shares and strengthens all provider journeys, adds404/429 reporting
   and repairs signed Gemini/Anthropic continuations. Deterministic, compiled
   and bounded native evidence is recorded in `parity-evidence-plan.md` and
   `docs/provider-model-audits.md`. Native429 and full native matrices remain open.
9. **Next, promoted by the user:** implement the approved offline catalog EDN
   extraction in `../plans/2026-09-23-offline-model-catalog.md`, preserving
   lookup/default behavior and compile-time embedding. This is separate from
   network discovery and provider/auth configuration.
10. **Pending:** complete the original shared-session coding/Attractor smoke
    journeys from `parity-evidence-plan.md`.
11. **Pending:** requirement-by-requirement final audit against original specs,
    compiled entry points and native integration evidence. OpenAI credentials,
    unobserved429 and unselected provider cells do not prove completion.

## Verification

- ITER-0021 final integration: `lgx test` on0.3.2 passes **1526 tests /
  13863 assertions / zero failures**, exit0. Log:
  `/tmp/attractor-provider-integrated-20260924.log`. Focused/impacted62/673/0
  in `/tmp/attractor-provider-focused-20260924.log`; paired spec and quality
  reviews approve, both progress auditors' final-suite condition is satisfied.
  Fresh compiled provider CLI five gates and main example validation pass.
  Bounded native Gemini/Anthropic subsets and their explicit residuals are
  recorded in `docs/provider-model-audits.md`.
- ITER-0019 final integration: `lgx test` on lgx 0.3.2 passes **1485 tests /
  13406 assertions / zero failures**, exit 0. Log:
  `/tmp/attractor-catalog-integrated-20260923.log`. Root focused checks pass
  137/822/0 in `/tmp/attractor-catalog-focused-20260923.log`; each quality
  reviewer independently passes the changed namespaces (16/169/0). Paired
  spec and quality reviews approve with no blocking findings. Fresh standalone
  `/tmp/attractor-catalog-cli-20260923 validate examples/hello.dot` reports
  5 nodes / 4 edges and no diagnostics; build log
  `/tmp/attractor-catalog-cli-build-20260923.log`. These are deterministic
  metadata/serialization checks, not native-provider availability evidence.
- ITER-0018 final integration: `lgx test` on lgx 0.3.2 passes **1481 tests /
  13376 assertions / zero failures**, exit 0. Log:
  `/tmp/attractor-schema-dialect-integrated-20260923.log`. The first integration
  had 12 failures in older fixtures storing invalid raw arrays in `$defs` or
  expecting the old malformed-URI diagnostic; log
  `/tmp/attractor-schema-dialect-initial-failures-20260923.log`. A gpt-6-luna
  fixture-only repair preserves valid/invalid array-index and escape coverage
  and explicitly rejects the old malformed schema. Root focused verification
  passes 108/616/0 in `/tmp/attractor-schema-fixtures-verified-20260923.log`.
  Both production and fixture changes passed paired spec and quality reviews.
  The mandatory official corpus has 46 files / 384 groups / 1301 cases, checked
  byte-for-byte against its pinned upstream revision. Eight bundled trusted
  meta-schemas match the published fixture documents.
- Fresh standalone `/tmp/attractor-schema-trusted-standalone-20260923 verify`
  passes six public validation cases from `/tmp` without test fixtures or network.
  Fresh `/tmp/attractor-schema-dialect-cli-20260923 validate examples/hello.dot`
  passes with 5 nodes / 4 edges and no diagnostics. Build logs:
  `/tmp/attractor-schema-trusted-standalone-build-20260923.log` and
  `/tmp/attractor-schema-dialect-cli-build-20260923.log`.
- ITER-0017 final integration: `lgx suite` on lgx 0.3.2 passes **1460 tests /
  11894 assertions / zero failures**, exit 0. Log:
  `/tmp/attractor-preparation-integrated-20260923.log`. The initial sandbox
  attempt could not write lgx's `~/.lgx/test-runner` harness; the approved retry
  completed. Fresh root focused proof is 40/327/0, paired reviews approve,
  and `/tmp/attractor-preparation-cli-20260923 validate examples/hello.dot`
  reports 5 nodes, 4 edges and no diagnostics. `git diff --check` passes.
- Native Gemini access rechecked on 2026-09-23 without logging credentials:
  the effective endpoint is Google's native API and model discovery returns
  HTTP 200. `gemini-2.5-flash` returns 404 despite appearing in discovery;
  an advertised `gemini-3.1-flash-lite` generation reaches the native endpoint
  and returns HTTP 402 / `RESOURCE_EXHAUSTED`, explicitly reporting depleted
  prepaid credits. This supersedes the old absent-Gemini-key assumption but
  does not supply successful native-provider evidence. Sanitized ignored
  artifacts: `evidence/native-gemini-preflight-20260923.edn`,
  `evidence/native-gemini-models-20260923.edn`, and
  `evidence/native-gemini-trace-20260923.edn`. OpenAI and Anthropic credentials
  are not configured in this environment. Local behavior work continues.
- ITER-0016 runtime SKIPPED repair passes fresh root impacted verification:
  208 tests / 1506 assertions / zero failures/errors, log
  `/tmp/attractor-skipped-final-focused-20260923.log`. Spec review's final
  forged-checkpoint case involving a context key containing `preferred_label`
  is repaired with parsed operand checks and regression tests. Fresh CLI
  `/tmp/attractor-skipped-cli-20260923` validates `examples/hello.dot`
  (5 nodes, 4 edges, no diagnostics); build log
  `/tmp/attractor-skipped-fresh-build-20260923.log`. The project binary also
  builds through lgx and validates the example. Both quality reviewers approve
  and each independently ran the 19-test / 138-assertion focused corpus.
- Integrated ITER-0015/0016 verification: `lgx suite` on lgx 0.3.2,
  **1453 tests / 11844 assertions / zero failures**, exit 0, log
  `/tmp/attractor-runtime-integrated-20260923.log`. This includes the repaired
  interrupted-verification readiness fixture and all schema reference cases.
  `git diff --check` passes. Schema dialect/meta-validation, preparation
  contracts, parity rows and native release evidence still remain open.
- ITER-0015 focused reference verification: `lg -source-paths src:test
  test/runner.lg` with 13 schema/structured-stream namespaces; 61 tests / 716
  assertions / zero failures/errors, exit 0. Log:
  `/tmp/attractor-schema-reference-focused-20260923.log`. Independent reviewer
  run: 31 tests / 514 assertions / zero failures/errors. Full integration:
  1434 tests / 11704 assertions / one failure, in task-runner interrupted
  verification attempt accounting (expected 2, observed 1). Schema tests pass.
  Log `/tmp/attractor-schema-reference-suite-20260923.log`; investigation
  delegated to a `gpt-6-luna` implementation subagent. Repair now waits for each
  real verifier's startup marker, then cancels it through the existing handler
  seam, with an independent safety deadline. Root and independent review agree
  this proves durable interrupted-attempt accounting without assuming 100ms
  process startup. Fresh root verification: 7 tests / 25 assertions / zero
  failures/errors, log `/tmp/attractor-runner-timing-verified-20260923.log`.
  Full-suite rerun follows the next runtime integration; no new pass claim yet.
- Reference snapshot standalone CLI build succeeds; binary
  `/tmp/attractor-schema-reference-cli-20260923` validates `examples/hello.dot`
  (5 nodes, 4 edges, no errors/warnings). Build log:
  `/tmp/attractor-schema-reference-build-20260923.log`.
- New contract failures observed before repair: 20/38 resource/dynamic/API
  assertions; 6/7 unresolved-reference applicator assertions; 2/4 `$id`-named
  pointer-container assertions. All now pass. URI helper has 57 assertions;
  initial RFC cases failed before implementation and malformed-reference
  regressions failed before their repair.
- Official fixture provenance, license and exact case counts are in
  `test/fixtures/json-schema/README.md`. API semantics and remaining dialect
  limits are in [schema-validation.md](../../schema-validation.md).

- Initial sandbox baseline: `lgx suite`, log
  `/tmp/attractor-spec-baseline-20260923.log`; failed because loopback listeners
  and process inspection are denied by the sandbox. Do not classify these as
  demonstrated product regressions.
- Final integration outside sandbox, after raw-read patch preflight:
  `lgx suite` delegates to the lgx 0.3.2 built-in runner; 1417 tests / 11275
  assertions / zero failures, exit 0. Log:
  `/tmp/attractor-spec-integrated-20260923.log`.
- Schema regression: `lg -source-paths src:test test/runner.lg
  attractor.schema-unevaluated-contract-test`; before implementation, 8 tests,
  68 assertions, 34 failures, no errors. Both public structured-output accessors
  accepted forbidden values before the fix.
- After implementation: schema/array/recursion/condition/dependency tests,
  22 tests / 161 assertions, zero failures/errors. Paired independent review
  found no annotation regression. The official draft2020-12 unevaluated corpus
  has 196 passing cases outside two relative-resource/dynamic-reference groups.
  Those groups' four cases remain unproved: two fail, two reject for the wrong
  reason. This is deliberately not recorded as 198 successful cases.
- User-requested tooling update: installed latest lgx 0.3.2 through mise;
  `lgx --version` confirms it. The built-in test runner passes the 8 schema
  regression tests / 68 assertions. `lgx suite` now delegates to `lgx test`.
  Initial new-runner snapshot: 1415 tests / 11265 assertions / zero failures,
  `/tmp/attractor-lgx-032-suite-20260923.log`; final results above include the
  two additional raw-capability preflight tests.
- Final focused root verification: environment editing, unevaluated schemas,
  structured streams, patches and profiles: 44 tests / 299 assertions / zero
  failures/errors. Final paired review's raw-capability finding is fixed:
  add-before-update patches reject before mutation if raw reads are unavailable,
  while add/delete-only patches remain valid without a raw reader.
- Fresh standalone CLI built at `/tmp/attractor-spec-closure-final-20260923`;
  its `validate examples/hello.dot` returns success with five nodes/four edges,
  zero errors/warnings. Build log: `/tmp/attractor-spec-build-20260923.log`.
- Annotation semantics source: [JSON Schema 2020-12 core](https://json-schema.org/draft/2020-12/json-schema-core),
  §§7.7, 10.2, 11. Additional dialect/reference work remains independently open.

Full objective remains active until all original requirements have adequate
current evidence. Partial repairs never imply overall conformance.

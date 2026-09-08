# Iteration Log

## ITER-0006 component — Artifact store/layout and EDN run metadata

**Verified:** 2026-09-07 from public `803ccb8`.

New root run metadata uses `manifest.edn`; legacy JSON bytes, external stage
`status.json`, and pinned `workflow/manifest.edn` remain unchanged. Public pipeline
tests exercise handler artifact metadata/checkpoints, real loop restart plus a
fresh run, and retrieval of earlier artifacts. Store contracts add exact 102,400/
102,401-byte boundaries, no-base fallback, metadata, file-to-memory replacement,
and failed-publication preservation of registration and bytes.

Clean RED: 3 tests / 40 passing and 17 failing assertions. Final focused and
standalone bundle: 3/64; impacted: 138/920; full baseline 644/5970 becomes 647/6034,
all zero failures, exit 0. CLI build/help pass; native-Go AOT is not inferred.
Paired scope, spec and quality reviews approve; final three-tier component audit
is clean.

This is the supported-value store/layout component of ATTR-ART-01 only. The
previous stronger discovery/resume promise is retained as pending adopted
ATTR-ART-02. Set-valued data exposed a separate local reader defect, filed as
let-go #823 after JVM comparison; non-evaluating round-trip validation continues
to reject it. Full reader and Attractor conformance remain incomplete.

## ITER-0008 component — Current-turn ownership (CAL-OWN-01)

**Verified:** 2026-09-07, from public baseline `1bdc933`.

Every admitted root input now establishes current ownership; queued follow-ups
retain it. Backend cancellation/failure atomically claims closure under the
lifecycle lock before performing cleanup outside it. Stale callers cannot close
or evict a successor, and completed callers do not inherit a successor's abort.
Direct input, public session-wide shutdown, and completion-callback reentry remain.

Permanent original RED: 1 test / 7 passing and 7 failing assertions. Final focused
and standalone bundled regression: 5 tests / 85 assertions. Fresh impacted suite:
198/1405. Full default baseline 639/5885 becomes 644/5970; all candidate results
have zero failures and exit 0. CLI build/help pass; native-Go AOT conformance is
not inferred. Paired scope/spec/quality reviews approve; review added the missing
fresh-publication/adoption and unused-session cleanup controls. Reusable evidence
and commands are in `docs/turn-ownership-evidence.edn`.
Paired final three-tier component audit is clean.

This completes the ownership component, not ITER-0008 or the Attractor goal.
Broader ordered shutdown, server streaming/events, and the remaining roadmap stay
open. No local let-go changes were needed; this was an Attractor lifecycle defect.

## ITER-0000 — Walking skeleton and deadline safety

**Completed:** 2026-09-04

**Stories delivered:** ATTR-DOT-01, ATTR-DOT-02, ATTR-ENG-01, ATTR-ENG-02, ATTR-CP-01, CAL-ENGINE-01.

**Tasks executed:** imported and verified the existing walking skeleton; hardened per-attempt deadlines and cooperative cancellation; snapshot the upstream specifications; established the iteration roadmap and evidence corpus.

**Scenarios:** SCN-ATTR-PARSE, SCN-ATTR-ENGINE, SCN-TIMEOUT, SCN-CHECKPOINT.

**Summary:** Deterministic mock pipeline journey; EDN checkpoint/artifact persistence; per-attempt timeout enforcement; cooperative cancellation through LLM requests, tool process groups, nested agents, manager and parallel branches; bounded polling; cancellation precedence; partial-output preservation.

- Evidence at revision `65f0403` on 2026-09-04: `LGX_LG=/Users/ndn/development/let-go/lg lgx test` reported 266 tests, 1,246 assertions, zero failures; `LGX_LG=/Users/ndn/development/let-go/lg lgx build` completed successfully. The specification-only revision `73e3a9d` did not change runtime behavior.
- Commits: timeout slice through `65f0403`; upstream specification snapshot `73e3a9d`.
- Project decision: internal serialization is EDN. JSON is retained only for provider/HTTP boundaries and explicitly external contracts such as `status.json`.

## ITER-0001 — Status-file contract

**Completed:** 2026-09-04

**Stories delivered:** ATTR-STATUS-01 and ATTR-STATUS-02.

**Tasks executed:** implemented the per-attempt resolver and shared status codec; added main/subgraph integration evidence; remediated evidence-review findings for canonical JSON and subgraph parity; remediated maintainability findings for shared validation and cancellation event precedence; added mutation-sensitive proof that auto-status is strictly a final fallback.

**Scenarios:** SCN-STATUS-FILE and SCN-AUTO-STATUS, including exhaustive shared resolver evidence, main-pipeline orchestration, and representative subgraph parity.

**Summary:** Per-attempt stale-file isolation; strict shared validation for handler outcomes and Appendix C status files; unknown-field tolerance; current-file precedence with handler fallback; exact auto-status synthesis; explicit-false inheritance; cancellation/timeout precedence; consistent routing, event, checkpoint, context-update, and canonical status persistence behavior across main and subgraph execution. Parallel evidence and maintainability reviews approved before audit.

- Evidence at revision `721d588` on 2026-09-04: the focused status-contract suite reported 31 tests, 192 assertions, zero failures; a deliberate temporary mutation that prioritized auto-status produced the expected two precedence failures before restoration; each impacted corpus marker plus the full command reported 298 tests, 1,440 assertions, zero failures; the four sentinel scenarios passed in the same full suite; `LGX_LG=/Users/ndn/development/let-go/lg lgx build` completed successfully.
- Commits: `31c8af7`, `f869d5f`, `0cf0247`, `0606ab0`, `83eeae9`, `d2b7675`, `9fc6846`, `55d5ff5`, `37315ca`, `721d588`.
- Safety: exact-file cleanup uses the file API; no recursive deletion command is present in source, tests, or iteration documentation.
- Audit: paired three-tier auditors returned CLEAN for ATTR-STATUS-01/02, SCN-STATUS-FILE/AUTO-STATUS, and all four sentinel scenarios.

## ITER-0002 — Public lifecycle preparation

**Completed:** 2026-09-04

**Stories delivered:** ATTR-DOT-03, ATTR-ENG-03, ATTR-VAL-01, and ATTR-XFORM-01.

**Tasks executed:** made subgraph-derived classes independent of declaration order and compositional across nesting; canonicalized all built-in and custom validation diagnostics; added the DOT-source `attractor.pipeline/prepare` and `attractor.pipeline/run` lifecycle; routed CLI and server entrypoints through that lifecycle; hardened the server's asynchronous preparation handoff against registration failures and late completion after timeout.

**Scenarios:** SCN-SUBGRAPH-LABEL, SCN-PUBLIC-LIFECYCLE, SCN-TRANSFORM-ORDER, and SCN-VALIDATION were completed; SCN-ATTR-ENGINE remained covered by the sentinel suite.

**Summary:** Subgraph labels now classify ordinary, repeated, pre-existing, edge-introduced, and transitively nested nodes without erasing explicit attributes or classes. Public preparation applies built-ins before ordered caller transforms, validates the final graph, and returns diagnostics without executing. Public run shares the complete-vector error gate, propagates non-error diagnostics, and is the single lifecycle used by CLI and server submission. Invalid and timed-out server preparations cannot create registry or engine side effects.

- Evidence at revision `5aeab8e` on 2026-09-04: all four exact scenario markers were present; the focused lifecycle suite reported 5 tests, 134 assertions, zero failures; the impacted and four sentinel scenarios passed in the full suite at 304 tests, 1,576 assertions, zero failures; `LGX_LG=/Users/ndn/development/let-go/lg lgx build` completed successfully.
- Commits: scope and implementation from `c2cce3d` through `5aeab8e`.
- Toolchain: `lgx.edn` requires let-go 1.12.2; the configured local compiler identifies as `v1.12.2-95-gbdd8268c9`.
- Safety: no `TODO(ITER-0002)` markers remain, and server timeout abandonment prevents late registration or execution.
- Reviews: every implementation task passed paired acceptance/evidence review and paired code-quality/boxing-in review before wrap-up.
- Audit: paired three-tier auditors returned CLEAN for ATTR-DOT-03, ATTR-ENG-03, ATTR-VAL-01, ATTR-XFORM-01, all five impacted scenarios, and all four sentinel scenarios.

## ITER-0003 — Run isolation and re-entry

**Completed:** 2026-09-04

**Stories delivered:** ATTR-CTX-01 and ATTR-ENG-05.

**Tasks executed:** defined the run-isolation contracts; implemented one-pass deep copying for context snapshots and branch clones; replaced recursive loop-restart re-entry with an invocation-wide iterative driver; isolated restart bookkeeping, files, handler runtimes, retries, and fidelity sessions while preserving semantic context and caller inputs; hardened step-budget and cleanup-error boundaries; restored complete engine-test discovery and separated internal codergen Outcomes from canonical external status persistence.

**Scenarios:** SCN-CONTEXT-ISOLATION and SCN-LOOP-RESTART.

**Summary:** Snapshots and clones rebuild the supported EDN container domain, including composite map keys and set members, reject unsupported values at deterministic paths, and keep branch logs independent. A selected `loop_restart=true` edge now re-enters iteratively under a pairwise-unique fresh root with exact event ordering, preserved graph/edge/caller identity, remirrored graph values, narrowly scrubbed bookkeeping, fresh run-scoped runtime state, unchanged prior files, and one invocation-wide positive step budget. Fidelity cleanup attempts every session close, honors ownership, and preserves primary errors.

- Evidence at revision `2307790` on 2026-09-04: the context-isolation suite reported 2 tests, 91 assertions, zero failures; the loop-restart suite reported 10 tests, 198 assertions, zero failures; all 43 engine tests were enumerated and passed with 195 assertions; the separate discovery sentinel reported 1 test, 2 assertions, zero failures; the full suite reported 334 tests, 1,918 assertions, zero failures; `LGX_LG=/Users/ndn/development/let-go/lg lgx build` completed successfully.
- Commits: `17e4ed8` through `2307790`.
- Audit remediation: the first paired audit found that an unmatched closing delimiter caused let-go's namespace loader to stop cleanly after engine test 26. Fixing the source exposed a real manager-artifact loss: codergen's self-written JSON status file narrowed its richer internal Outcome. The engine now marks managed invocations so codergen returns the complete internal Outcome while the engine persists canonical JSON; direct handler status behavior and custom file authority remain unchanged. A separate sentinel asserts all 43 engine test vars, including the final test, are loaded.
- Safety and policy: no `TODO(ITER-0003)` or `FIXME` markers remain; no recursive deletion command was introduced; EDN remains the internal persistence format and JSON remains limited to external contracts.
- Reviews: every implementation task passed paired acceptance/evidence review and paired code-quality/boxing-in review. After remediation, two independent three-tier auditors returned CLEAN for ATTR-CTX-01, ATTR-ENG-05, all impacted engine/status/manager/fidelity/resume/cancellation behavior, and the four sentinel scenarios.

## Component checkpoint — Session error recovery (2026-09-07)

CAL-ERROR-01 remains partial; ITER-0008 remains in progress. This checkpoint
delivers SCN-CAL-CONTEXT-RECOVERY, not the broader failure/shutdown scenario.
Typed stream errors retain their SDK identity, authentication stays fatal, and
context overflow fails only the current input while retaining a usable session.
All new HTTP fixture/checker code is let-go with owned process lifetimes.

Evidence: baseline 604/5502/0; core RED 5 tests, 113 pass/64 fail; GREEN 5/177/0;
impacted 62/949/0; final default suite 609/5679/0. Native HTTP checks pass 8/8
through four adapters. The standalone core bundle passes 5/177 from /tmp, build
and CLI help pass, and paired independent spec/quality reviews approve.
See `docs/session-error-contract.md` and its EDN evidence record for commands,
scope and explicit native HTTP cancellation/SSE/live-provider/AOT residuals.

## Component checkpoint — Hook stdin transport

ATTR-HOOK-01 remains incomplete. SCN-TOOL-HOOKS-STDIN adds an optional local
execution operation with private file-backed stdin, preserving existing owned
command cancellation and four-argument callers. Payloads are not embedded in argv
or evaluated by the shell. Cleanup reports failures, retains command results and
primary error details, and attempts both owned removals.

Evidence: baseline 609/5679/0; initial missing-capability RED 2 pass/1 fail;
review regression RED 62 pass/7 fail; focused 7/74/0; impacted execution 36/185/0;
final default 616/5753/0. Standalone bundle 7/74/0; CLI build/help pass. Paired
scope/spec/quality reviews approve. See `docs/tool-hooks-plan.md` for commands,
failure semantics and remaining agent/workflow integration. No native-Go AOT
conformance or complete hooks behavior is claimed by this component.

## Component checkpoint — Tool-call hooks

ATTR-HOOK-01 / SCN-TOOL-HOOKS is verified. Graph/node hooks execute through agent
environments with literal-key JSON stdin, environment metadata, pre veto and
nonblocking post auditing. EDN stage records, per-call context pinning, refreshed
fidelity defaults, descendant and parallel isolation, pending/busy admission
ownership, cancellation and captured recovery have permanent tests.

Evidence: baseline 616/5753/0; standalone core 12/85/0; workflow 11/47/0; combined
and external-directory bundle 23/132/0; impacted agent/engine/status/recovery
203/1579/0; full default suite 639/5885/0. CLI build/help pass. Paired spec and
quality reviews approve. `docs/tool-hooks.md` documents use and
`docs/tool-hooks-evidence.edn` records reusable verification.

ITER-0007 and the full goal remain incomplete. Audit discovered a separately
verified preexisting stale-turn cancellation race at the completion callback
handoff; CAL-OWN-01 / SCN-CAL-TURN-OWNERSHIP records the pending regression/fix in
ITER-0008. No native-Go AOT conformance is inferred from these bundle/build checks.

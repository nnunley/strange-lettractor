# Iteration Log

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
- Audit: paired three-tier evidence audit pending.

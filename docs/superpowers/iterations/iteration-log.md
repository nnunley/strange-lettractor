# Iteration Log

## ITER-0007 component — File images and binary rejection

**Verified:** 2026-09-07 from public `892db06`; final paired component audit clean.

**Completed:** implementation, verification and component audit on 2026-09-07; not iteration completion.
**Stories delivered:** CAL-TOOLS-01 implemented-format read_file component; full story remains partial.
**Tasks executed:** local reader; SDK attachment encoding/compatibility; agent and Gemini batch propagation.
**Scenarios:** SCN-CAL-READ-FILE, with impacted tool truncation/hooks/agent/profile/SDK checks.
**Summary:** byte-preserving image continuation and binary rejection, with complete raw evidence.

`SCN-CAL-READ-FILE` adds real local text/binary/image reads, explicit base64 and
ordered SDK image results, and actual agent-to-provider continuation for all
three built-in families. Gemini mixed batches preserve path/image ordering;
hooks/events retain untruncated descriptions and metadata, while only model text
is truncated. Malformed attachments become tool errors. Legacy raw-image, nullable
field, omitted/structured SDK content and ordinary executor output remain compatible.

Permanent RED evidence caught binary/image handling, WebP character-versus-byte
offset assumptions, missing encoded attachments, nullable-field regressions and
description loss in plural/batch normalization. All repairs have reusable tests.
Focused and standalone bundle pass 14 tests / 439 assertions; impacted runner
passes 217/1667; default full suite passes 667/6507 against baseline 653/6068.
All terminal exits are zero; CLI build/help and paired per-task spec/quality gates
pass. `docs/read-file-contract-evidence.edn` records the staged evidence.

No let-go runtime defect was identified or runtime source changed. Recognition
covers PNG/JPEG/GIF/WebP signatures, not image decoding or universal provider
acceptance. Other formats, live vision quality, provider-reference fidelity,
remaining coding-agent tool requirements and native-Go AOT parity are not closed.
CAL-TOOLS-01 and ITER-0007 remain incomplete; the full Attractor goal stays active.

## ITER-0006 component — Shared queue and interviewer matrix

**Verified:** 2026-09-07 from public `6d6e813`.

**Completed:** 2026-09-07, component only.
**Stories delivered:** ATTR-HUM-01; ITER-0006 remains incomplete.
**Tasks executed:** queue claim serialization, constructor compatibility, interviewer matrix evidence.
**Scenarios:** shared parallel queue and public interviewer matrix.
**Summary:** atomic queue claims with false/nil occupancy and native runtime breadcrumbs.

QueueInterviewer now claims answers atomically through one shared instance,
consumes false/nil scalar entries, and retains its factory and one-argument
constructor. A narrow per-instance boolean-CAS lock protects only dequeue; answer
normalization and recording remain outside. Direct external atom mutation and
multiple instances wrapping the same atom are not coordinated by that lock.

Permanent pre-fix RED: 16 tests / 125 passing and 7 failing assertions. Final
interviewer suite: 18 tests / 143 assertions, including four new queue scenarios
and two handler fallback/no-edge cases alongside the existing twelve tests.
Public parallel gates correlate recorded pairs with checkpoint branch outcomes
without assuming scheduling order. Focused and standalone bundle pass 18/143,
impacted 119/924, full baseline 647/6034 becomes 653/6068; all zero failures,
exit 0. CLI build/help pass. Paired scope/spec/quality reviews approve; final
three-tier component audit is clean.

The native atomic-update alternatives exposed two independently reproduced local
runtime defects, filed as let-go #824 with JVM comparisons. The workaround has
an explicit restoration breadcrumb. Native console timeout remains ATTR-HUM-02;
this component closes ATTR-HUM-01, not ITER-0006 or the full goal. Native-Go AOT
conformance is not inferred from bundle/build success.

## ITER-0006 component — Artifact store/layout and EDN run metadata

**Verified:** 2026-09-07 from public `803ccb8`.

**Completed:** 2026-09-07, supported-value component only.
**Stories delivered:** ATTR-ART-01 store/layout; adopted discovery remains ATTR-ART-02.
**Tasks executed:** EDN run metadata and artifact lifecycle/layout evidence.
**Scenarios:** artifact threshold, publication failure, public restart and prior-file preservation.
**Summary:** EDN root metadata and supported-value artifact storage, retaining reader limitations.

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

**Completed:** 2026-09-07, ownership component only.
**Stories delivered:** CAL-OWN-01; ITER-0008 remains incomplete.
**Tasks executed:** current-turn ownership, stale cleanup fencing, handoff and adoption regressions.
**Scenarios:** SCN-CAL-TURN-OWNERSHIP.
**Summary:** stale invocations cannot close or evict a newly admitted successor.

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

## Component checkpoint — Subagent lifecycle ownership (2026-09-08)

**Completed:** 2026-09-08, scoped component; paired final audit clean.
**Stories delivered:** CAL-SUBAGENT-01 ownership component only; story stays partial.
**Tasks executed:** reproduce close/admission/handoff races; implement parent-owned
run admission and completion queues; preserve terminal cancellation; guard nested
event delivery against self-join; repair overlapping-close and turn-count defects.
**Scenarios:** SCN-CAL-SUBAGENTS lifecycle ownership component.
**Summary:** Wait captures a prepublished run promise, accepted messages drain
through that run, shutdown cannot orphan admitted children, and late completion
cannot resurrect cancelled handles. Actual Codex and Claude Code reviewers
approve spec compliance and code quality. Native controlled barriers exercise
both admission orderings and old/new public waiter selection.

Evidence: baseline 667/6507; focused/bundle 12/106; impacted 166/1044; default full
suite 679/6613, zero failures and terminal exit 0. CLI build/help pass. The first
impacted run correctly caught a turn-count ordering regression; it was repaired,
not waived. See `docs/subagent-lifecycle-evidence.edn` for commands and scope.
Profile/model/directory fidelity, remaining depth/live proof, general event
shutdown and native-Go AOT parity remain open. No console/TUI code is included.

## Component checkpoint — Console input framing (2026-09-08)

**Completed:** 2026-09-08, pure frontend component; paired final audit clean.
**Stories delivered:** CONSOLE-INPUT-01 only, user-requested extension.
**Tasks executed:** reviewed input contract, red/green reducer implementation,
focused/full/bundle verification, native nREPL capability investigation.
**Scenarios:** SCN-CONSOLE-INPUT at the public pure reducer seam.
**Summary:** Agent text, slash commands and explicit evaluation requests remain
distinct data. Multiline draft cancellation cannot cancel a worker, selection
is captured at submission, and no input is evaluated by the router.

Evidence: baseline 679/6613/0; focused/outside-checkout bundle 7/92/0; full suite
686/6705/0, terminal exit 0. CLI build/help pass. Paired scope/spec/quality reviews
include actual Claude Code CLI; paired final audit clean. These direct CLI reviews
are not Attractor-managed Claude workers. Private notes excluded.

The console is a client of a future RPC hub, not the owner of the framework.
Stock nREPL gaps and existing upstream issues are in `docs/nrepl-hub-findings.md`.
Hub/eval/TUI/worker integration and all outstanding StrongDM requirements remain
open; no native-Go AOT or usable console command is claimed by this component.

## Component checkpoint — LLM operation ownership (2026-09-08)

**Completed:** 2026-09-08, shared LLM correctness component under standing
transparent-fix authorization; does not close ITER-0010.
**Stories delivered:** ULLM-CANCEL-01 ownership slice only; ULLM-ERROR-01 unchanged.
**Tasks executed:** filed nooga/let-go#829 (lazy-seq realization context) with the
pure reproducer; added local runtime `scope-cancelled?` (#830) and streamed
`http/serve` bodies (#831); hardened the persistent operation owner with idle
parent-cancellation proof; integrated generate, lazy stream reads and tool rounds
into owned jobs and removed the unowned stream monitor; made tool dispatch eager
so cancellation reaches tool workers; extended the let-go loopback fixture with
held-body, held-JSON, paced SSE and tool-continuation scenarios.
**Scenarios:** SCN-ULLM-CANCEL at the shared adapter seam and native OpenAI
loopback seam; SCN-OWNER focused owner witnesses.

Evidence: baseline 758/7146/0; owner focused 24/110/0; shared ownership regressions
8 failures → 9/35/0 after review fixes; native ownership check 12 failures → 3/67/0 twice; discovery
loopback 3/39/0; three impacted namespaces 107/803/0; full suite 791/7291/0,
exit 0; focused outside-checkout bundle 33/145/0; CLI build/help pass; let-go
`go vet`, `pkg/rt`, `pkg/vm`, `pkg/api`, `test/e2e`, the full jank Clojure
suite (243 cases) and the native-entry gate pass on runtime `8c1e6ee4`. The `cancellation-during-error-read-wins-over-http-error` harness
was simplified: it hooked the removed polling `deref`; every behavioral assertion
is retained. Independent read-only review ran through the Attractor Claude
connector; eight of eleven findings were accepted and fixed with regression
tests, two were rejected with evidence, one recorded as a limitation (see
`docs/llm-operation-ownership.md`). The review exposed nooga/let-go#832
(`bound-fn*` detached calls from the caller's scope), fixed locally.

Not claimed: adapter connect/request/read timeout distinctions, the remaining
status/drop/retry matrix, server-observed disconnects, cancellation of work inside
lazy-seq thunks (runtime #829), or interruption of callbacks that ignore the
combined abort signal.

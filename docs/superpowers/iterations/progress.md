# Progress

**Phase:** implementing ITER-0006
**Task:** fan-in component reviewed and verified; interviewer matrix/nonblocking console timeout next
**Iterations:** 6 complete, 8 pending
**Sentinel corpus:** 4 established; post-merge main at `ac7b241`: 473 tests / 3,370 assertions / 0 failures. Separate deferred reader check: 1 test / 5 failed assertions.
**Current iteration:** ITER-0006 — interactive concurrency; ATTR-PAR-02 component complete, iteration incomplete

**Fan-in completion checkpoint:** Public proof `b51a386`, spec corrections
`bbb1471`, and failure-path fixture teardown `b87269c` passed independent spec
then quality review. Root full suite at `bbb1471`: 530 tests / 3874 assertions /
zero failures; AOT exit 0. After the test-only teardown correction, root focused
public proof passes 4/110/0. A fresh compiled heuristic run selects and persists
`a`; the offline HTTP prompted run below selects `b`. ATTR-FANIN-01 and
SCN-FANIN-RANKING are complete as this component only. Interviewers, console
timeouts, artifact lifecycle/recovery, and the registry-to-engine matrix remain
required before ITER-0006 audit/integration. Source inspection confirms the next
gap: console questions still use unconditional `read-line` and ignore
`timeout_seconds`, contrary to upstream §§6.4–6.5.

**Public fan-in verification at `b51a386`:** Root independently ran the default
suite: 530 tests / 3840 assertions / zero failures, exit 0; local AOT build exits
0. Separate reader acceptance remains 1 test / 5 failures, exit 1. A compiled
workflow using actual tool branches and a one-request localhost OpenAI Responses
fixture succeeds. Captured HTTP payload has the configured model, strict integer
candidate-index schema, no tools, and both complete ordered branch records. The
saved checkpoint selects `b` against heuristic ID order and completes
`[start fork join exit]`. Fixture evidence is retained under
`/tmp/lettractor-fanin-wire.VlJNob/`; this is offline HTTP evidence, not live-provider
parity. Initial sandbox-denied connection is retained separately from the
successful authorized run.

An implementer full-suite run (session 64423) reported 530/3840/**1 failure**.
Its exact assertion was lost to output truncation; the missing region was within
the LLM test listing, while all four new public fan-in tests were visibly green.
Do not classify that failure as fixed. Root's full rerun passed, and a subsequent
ten-run LLM-only check retained every repetition summary: each 83 tests / 494
assertions / zero failures. The historical failure remains unreproduced, with no
justification for a speculative runtime change. Future failures require complete
captured diagnostics. Task 3 spec review requested stronger final-checkpoint,
complete candidate-envelope and deep registry-state assertions; no component
completion marker is authorized until those corrections pass both reviews.

**Latest fan-in adapter checkpoint:** `3f8e9f5` adds the real unified-client ranker
and CLI run/resume wiring; `4c704cb` rejects empty parsed model/provider before any
provider call; `6608811` proves exceptional caller-scope restoration. Both Task 2
reviews approve. Root full suite passes 526/3764/0 after reviewed test-only manager
deadline stabilization `c4bbc15`; the original 100ms deadline is unchanged. AOT
passes; compiled prompted --mock execution fails explicitly and persists no winner.
Separate reader acceptance remains 5 failures. Public real-ranker lifecycle,
pinned recovery, and cancellation/timeout evidence are still Task 3. The shared
client caller-abort/worker-cleanup distinction is recorded under ULLM-CANCEL-01;
ranker-owned native scopes supply the workflow's stronger joined-cleanup guarantee.
UUID string coercion difference is tracked as let-go #809 with restoration notes.

**Fan-in checkpoint:** `cf03766` implements score-aware deterministic and injected
selection; `901dfa4` strengthens parent-context, status-order and tie evidence.
Both Task 1 review gates approved. Root verified 508 tests / 3649 assertions /
zero failures, AOT success, and compiled heuristic fan-in/checkpoint success.
Focused evidence is 17/64/0; separate reader acceptance still fails 5 assertions.
Real LLM adapter, CLI run/resume configuration and public recovery/cancellation
proof remain Tasks 2–3; ATTR-FANIN-01 is not yet complete. Additional let-go unary
negation bug [#808](https://github.com/nooga/let-go/issues/808) is reproduced against
JVM Clojure and linked in the restoration checklist; the selector compares scores
directly to remain safe even after upstream checked overflow is restored.

**Latest component checkpoint:** Task 1 (`4851b51`, `84dffe9`) and public Task 2 (`7a150be`) passed independent spec and quality reviews. Task 2 public cancellation barriers passed without runtime changes; its primary-error/cleanup regression failed 2 assertions before the scoped engine fix. Final focused evidence is 18/215/0; root independently verified full default suite 491/3585/0, local AOT exit 0, and compiled parallel workflow/checkpoint success. Separate reader acceptance remains 1 test / 5 failed assertions / exit 1. SCN-FIRST-SUCCESS and ATTR-PAR-02 are complete only as this component; interviewer, fan-in ranking, artifact lifecycle, and registry matrix work remain required before iteration audit/integration. [Upstream restoration checklist](../../let-go-followups.md) tracks #801, #805, #806, and #807, affected code, and removal/regression checks.

**ITER-0006 start:** User approved the design direction. Work is isolated in `.worktrees/iter-0006-interactive-concurrency`; fresh default-suite baseline at `38e9c9e` passes 473/3370/0. Two independent scope/spec reviews approved the parallel-join component and the implementation plan passed review. Design/plan and the independently reproduced [future exception compatibility finding](../../let-go-future-compatibility.md) are pushed at `f249180`. Task 1 follows test-first implementation. Interviewers, fan-in ranking, artifact recovery/discovery, and handler-matrix evidence remain required after this component. The five reader acceptance failures remain unmet and separate from the passing default suite.

**Integration checkpoint:** Main was fast-forwarded to `ac7b241` after both independent three-tier audits returned scoped CLEAN. The post-merge full suite passes 473/3370/0 and local let-go AOT builds successfully. A fresh compiled `examples/composition-parent.dot` run succeeds and its saved checkpoint contains `child.result = "hello-from-child"`. Public main was pushed and remotely verified at `7d097b4`; the iteration branch was remotely verified at `ac7b241`. All worktrees and untracked private notes are preserved. ATTR-READ-01 and ATTR-COMPOSE-02 remain unresolved full-goal requirements; see [iteration audit](iter-0005-audit.md). Historical task checkpoints below describe their state at the time, not current integration status.

**Latest review:** The composition plan passed its chunk reviews. Task 1 configuration review found reader-syntax gaps. The user authorized a temporary ordinary-map path while native reader compatibility remains unresolved; do not count this as full Clojure-reader conformance. Pinned recovery was merged and pushed to public main at `f67cdc6` after both audits returned CLEAN; see [audit evidence](iter-0004-audit.md).

**Last event:** 2026-09-06 — Temporary mapping checkpoint `6eda27f` is pushed and passed scope and code-quality review with no blocking findings. Task 2 resolver implementation has started. Default mapping tests pass 7/163/0, public lifecycle passes 8/159/0, and the default suite passes 412/2694/0. The separate `compat/run_mapping.lg` command runs the five unresolved reader acceptance assertions and exits 1. Local-compiler AOT build succeeded; the compiled CLI accepts ordinary mapping configuration and rejects an engine-owned `run.id` destination with `subpipeline_config`. These checks do not yet prove child resolution or execution. [Reader issue #801](https://github.com/nooga/let-go/issues/801) remains open. No local let-go or PEG changes are part of this work. Executable-packet and skill-package design is deferred until a working Attractor is available.

**Nonblocking review follow-up:** Add exact diagnostic-key-set and multi-node lexical diagnostic-order assertions when extending composition evidence. Current implementation conforms; these are test-strengthening opportunities, not proved implementation defects.

**Task 2 handoff:** `2c06f76` is pushed and passed both scope and quality review. Root independently confirmed capture 11/45/0 and the full default suite 423/2739/0. Task 3 is underway: recursive public prepare, physical-source reuse, cycles/alias identities, and bundle cross-reference verification. Read-only probes confirm the current root-only verifier accepts rehashed dangling-reference and missing-primary records; Task 3 must add permanent rejection tests and semantic validation before recursive bundles are used. Those probes do not execute workflows or write run artifacts.

**Task 3 verification checkpoint:** Recursive capture is committed at `15d6609`, with review fixes at `61409c1`. Root independently ran the original recursive suite (13 tests / 83 assertions / 0 failures) and default suite (436/2822/0). Compiled CLI testing then exposed a file-origin handoff gap: `validate` and `graph` called source-only preparation, causing valid relative children to fail with `:missing-base-dir`. Spec review also found that a rehashed bundle could make the root an alias of another primary, violating root-first identity. Both fixes now pass spec and code-quality review with no remaining findings. Mutation-sensitive regression evidence includes 10 CLI assertion failures and two runtime/persisted root-alias failures before correction. Final focused results are recursive 14/85/0, CLI 6/57/0, and lifecycle 8/161/0. Root's independent post-fix default suite passes 438/2839/0, and local-compiler AOT builds successfully. The compiled executable accepts valid relative-child fixtures through `validate` and `lint`, inspects the graph successfully, and rejects a real source cycle with exit 1 and canonical `subpipeline_cycle`. Task 3 is complete; selected-plan checkpoint recovery and mapped child execution remain Tasks 4 and 5, respectively. This is not completion of ITER-0005 or the full Attractor specification.

**Task 4 handoff:** Selected-plan recovery (`37873d8`, `23c3758`) passed scope and quality review. Checkpoints preserve explicit plan identity (including invalid values for later rejection), legacy absence selects the original root, and selected aliases survive resume and restart without changing closure identity. Fresh and resumed engines receive protected captured-bundle descendant callbacks. Quality review caught public `pipeline/run` forwarding an internal selector after publication; the fix makes public runs always select the root, with four invalid/child-selector regression cases. Root independently verified the final default suite 447/2927/0 and AOT build. A compiled CLI resume completed an interrupted three-node child, retained its exact child plan ID, and reverified the unchanged full two-plan capture. Task 4 is complete; Task 5 must now install the scoped subpipeline handler and implement isolated, transactional mappings. Full Clojure reader support, Task 6 composition scenarios, and Task 7 iteration audit/integration remain unproved.

**Task 5 verification checkpoint:** `ea08d98` implements the scoped mapped-child handler and has passed independent spec and code-quality review with no remaining findings. Mapping contracts pass 16/114/0; affected composition, handlers, lifecycle, context-isolation, status, and engine checks pass 113/871/0. Root independently verified the final default suite at 463/3041/0 and rebuilt with local let-go AOT. A fresh compiled real-file parent/child run exits 0 and stores `child.result = "mapped-aot"` in the parent checkpoint; the child checkpoint selects `workflow://root/child.dot`, contains only `begin/work/end`, and shares the closure fingerprint. Initial artifact inspection used the wrong `:context` field; the corrected check reads the checkpoint's actual `:context_values` field and verifies the mapped value.

Pre-review fixes preserve child failure/cancellation metadata, inherit node timeout cancellation, and confine subpipeline status cleanup/writes as well as child publication. Root reproduced a dangling status symlink creating a file outside the parent run before the fix; afterward the same probe returns nonretryable `subpipeline_configuration_error`, invokes no handler, and creates no outside file. The permanent dangling-link regression went from four failures to green; a preexisting UUID child-root regression went from two failures to green. Child path checks inspect directory entries because `io/file-exists?` follows symlinks and misses dangling ones. This is pre-write confinement, not protection against hostile concurrent filesystem replacement.

A compiled three-level baseline also succeeds: parent, middle, and leaf checkpoints select `workflow://root`, `workflow://root/middle.dot`, and `workflow://root/child.dot` respectively, share one nonempty SHA-256 closure fingerprint, and contain separate completed-node vectors. The grandchild's `tool.output` reaches the parent's `nested.result` through both explicit output mappings. This smoke test does not exercise interruption or cancellation.

After editing the temporary grandchild source, compiled resume of the completed parent reports `workflow_drift`, retains `nested.result = "mapped-aot"`, and leaves both child and grandchild attempt counts at one. This establishes the completed-run skip baseline, not interrupted-child recovery.

Task 5 is complete, but the iteration is not. Task 6 must prove nested cancellation/event ordering, independently exhausted budgets, descendant/restart custom-handler behavior, and captured interrupted-child recovery. The local compiler's separately confirmed silent unfinished-trailing-form bug is recorded in [reader compatibility findings](../../let-go-reader-compatibility.md); check test discovery counts as well as failure totals.

**Task 6 independent recovery baseline:** At runtime commit `ea08d98`, root cancelled a real-file parent run at the child's `work` stage-start event. The parent returned CANCELLED with completed nodes `[start]`; the child's checkpoint retained `[begin]`. Root hashed all eight existing child files, changed the current child tool command, then resumed the parent checkpoint through the compiled CLI. Resume reports `workflow_drift` and succeeds with the captured output `interrupted-captured`, not the replacement command's output. There are now two child attempts; parent completion is `[start child exit]`. The old child checkpoint still contains `[begin]`, and all eight old file hashes are unchanged. This is a verified at-least-once fresh-child recovery baseline, not proof of every Task 6 cancellation boundary. Permanent nested contract tests are in progress.

Root then copied the interrupted child run to a separate temporary directory and moved the current child source aside. Compiled resume of the copied child checkpoint reports missing-source drift and succeeds with selected plan `workflow://root/child.dot`, completed nodes `[begin work end]`, and `tool.output = "interrupted-captured"`. The original interrupted child's eight hashes still match. The source was moved, not deleted; all temporary evidence was preserved. This verifies independently selected child recovery without relying on current source bytes.

**Task 6 review checkpoint:** Test-only commits `49d402a` and `bfdc5a3` add ten permanent public nested scenarios (329 assertions). No production defect emerged. Spec review requested stronger checks for recursively wrapped terminal events before cleanup, node-timeout cancellation through both child levels, and custom-handler inheritance through the actual captured callback. All three additions now pass spec re-review and code-quality review with no remaining findings. Root's independent final default suite passes 473/3370/0; focused recovery passes 52/481/0. The additional tests use controlled cleanup barriers and an injected clock, exercise node/default/fallback and restart-global budgets, compare every old child/grandchild artifact byte after parent recovery, and prove state consumption and cleanup across root/child/grandchild/sibling runs. The paired iteration-wide audit is underway; main integration has not occurred. A fresh compatibility run still fails all five deferred reader assertions, while the local AOT build succeeds.

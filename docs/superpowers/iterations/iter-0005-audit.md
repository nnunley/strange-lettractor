# ITER-0005 audit

Date: 2026-09-06. Baseline: `f67cdc6`, 405 tests / 2,531 assertions / 0 failures.
Audited implementation: `bfdc5a3`; later documentation records the same runtime.

## Verdict

Both independent auditors returned **CLEAN for the approved subpipeline scope**.
No new runtime defect or sentinel regression was found. This is not whole-project
conformance: full Clojure-reader support and graph-merging execution evidence
remain explicit residual requirements below. Main integration is verified
separately after the audit.

## Evidence

| Check | Result |
|---|---|
| Root final default suite | 473 tests / 3,370 assertions / 0 failures |
| Auditor A deep composition/capture/selection | 67 / 823 / 0 |
| Auditor A impacted contracts and sentinels | 158 / 1,363 / 0 |
| Auditor B deep composition/capture/selection | 67 / 823 / 0 |
| Auditor B impacted contracts and sentinels | 179 / 1,461 / 0 |
| Auditor B execution/agent/environment/handlers/CLI | 97 / 400 / 0 |
| Local let-go AOT build | Pass |
| Full-reader compatibility acceptance | 1 test / 5 failed assertions / exit 1 |

Auditors used independent native runners, not simultaneous lgx invocations that
could overwrite a shared test harness. All reported sessions completed. The
auditing skill's shared PAR templates were absent locally; its available
three-tier instructions were applied with two independent reviewers.

## Three-tier findings

Deep evidence is adequate for ordinary mapping syntax/defaults, nil/presence,
destination ownership, mapped-only deep copying, structural error paths,
transactional outputs, and exact failure/cancellation metadata. Source tests
prove authorization before read, UTF-8 handling, deterministic recursive
preparation, aliases/cycles/collisions, diagnostics, and complete closure binding.
Selected-plan tests prove protected callbacks, root/child identity, legacy
checkpoints, invalid selectors, and restart preservation.

Mapped/nested integration proves safe stage/child paths including dangling links
and UUID collisions, cloned registries and real custom-handler inheritance,
separate runtime state through mutation/consumption, independent and restart-global
budgets, exact event envelopes, and pipeline/node-timeout cancellation through a
grandchild. Controlled cleanup barriers prohibit any recursively wrapped terminal
event before join. Interrupted-parent recovery creates fresh attempts while every
old child artifact remains unchanged; selected child/grandchild checkpoints resume
captured graphs after source changes or deletion.

Impacted pinned recovery, public lifecycle/CLI/server, context isolation, restart,
status/auto-status, validation/transforms, and engine contracts pass. Parser,
engine, timeout, and checkpoint sentinels show no regression. No unrequested
runtime feature was identified.

Compiled CLI evidence supplements the permanent tests: two- and three-level
output mapping and checkpoint identities; completed-parent skip after source
drift; cancelled-parent fresh-child recovery after a source edit with eight old
artifact hashes unchanged; and copied interrupted-child recovery while its
current source is absent. See [progress](progress.md) for observations.

## Full-goal residuals

- **ATTR-READ-01:** The approved ordinary-map workaround is not the intended
  Clojure-reader superset. Five compatibility assertions remain failing. An
  upstream fix must be followed by native-reader integration and application
  acceptance evidence; preserve `.edn` filenames and prohibit evaluation.
- **ATTR-COMPOSE-02:** Both auditors found no reusable valid transform that merges
  another graph's nodes **and edges**, then validates, captures, and executes the
  merged route. Existing arbitrary transforms are the intended seam; no built-in
  merger API is implied. This is separate from the approved non-inlining
  subpipeline implementation.

These requirements, scenarios, and runnable residual gates are retained in the
requirements/corpus and ITER-0013 roadmap entry. Independent graph-merging proof
may be brought forward; the reader dependency does not block unrelated iterations.

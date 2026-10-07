# Attractor convergence and continual training implementation plan

> For agentic workers: use subagent-driven-development with test-first repairs,
> followed by separate specification and code-quality review. Google imported
> code-review guidelines apply. Commit bounded working changes on
> `audit/continual-harness-convergence`; root coordinates the shared index.

**Goal:** repair the audited runtime contracts, implement a reliable core Continual
Harness aligned with arXiv:2605.09998, and provide executable model-training
infrastructure with preserved environment state.

**Architecture:** retain the existing hub, pipeline, agent registry, execution
environment and provider layers. Reuse owned execution scopes for every timeout
and cancellation boundary. Keep host policy fixed while exposing a separately
replaceable adaptive task prompt. Training is an explicit operator-configured
pipeline over persisted data and model artifacts, never a prompt claiming to have
changed weights. No new vendor dependency or GPU requirement for deterministic
tests; a trainer command is a real process integration boundary.

The core harness is independently usable and has no trainer requirement. Training
commands are validated and invoked only by explicitly selected co-learning mode;
ordinary agent and workflow sessions never require them.

**Stack:** pinned let-go/lgx, existing native subprocess and JSON/EDN interfaces,
clojure.test and local fixture processes.

## Baseline and review evidence

- Existing harness checkpoint: `dfa3fed`.
- Findings and reproduced failures: `docs/codebase-audit-2026-10-07.md`.
- Local probes/logs: `evidence/codebase-audit-2026-10-07/`.
- Paper: https://arxiv.org/html/2605.09998v1 §§2–3 and Appendix D.
- User explicitly included model-training infrastructure on 2026-10-07.

## Task 1: Core harness ownership, adaptation and persistence

Files: `src/attractor/{agent,harness,evaluator,refiner}.lg`, existing corresponding
test namespaces. Root owns CLI, handlers and all documentation integration;
implementation workers do not edit these shared files.

- [x] Convert R03, R05–R07, R13–R18 reproductions into permanent failing tests.
- [x] Run tests and preserve red output in ignored evidence.
- [x] Keep callbacks/refiner I/O outside the session mutex; propagate session abort.
- [x] Use owned scopes and joined cleanup for interactive evaluation. Compile only
  a function expression for dynamic tools; do not silently evaluate arbitrary
  top-level forms or replay exceptions with another arity.
- [x] Make ledger edits validated and registry-aware: create/update/delete and
  rollback must agree with what normal dispatch can call. Restore JSON and EDN
  with equivalent typed internal state, accurate errors and restoration counts.
- [x] Add explicit harness storage configuration, atomic save after committed edits
  and lifecycle persistence. Reopen a real session without test-side saving.
- [x] Introduce actual step-based scheduling with warmup and interval; parse the
  documented node attributes. Disabled automatic refinement must remain disabled.
- [x] Feed actual tool-result history and retained failure knowledge to refinement.
  Apply four component passes through a shared validated edit interface; preserve
  immutable host policy and separately update an adaptive task prompt.
- [x] Prove a deterministic failed routine is repaired, invoked next, and survives
  reload without resetting environment/history. Preserve actual role subagents.
- [x] Route normal agent requests through the same retry seam as injected clients.
- [x] Run focused agent/lifecycle/harness suites, review, and commit.

## Task 2: Executable co-learning infrastructure

Files: new `src/attractor/co_learning.lg`,
`test/attractor/co_learning_test.lg`, a local trainer fixture, existing CLI/hub
wiring and continual-harness example. One module owns the new dataflow; avoid
one file per decorative stage.

- [x] Test a persistent two-iteration environment with immutable input/output
  artifact contracts and a trainer process that actually writes a new model artifact.
- [x] Validate operator config before invoking commands. Define rollout, scoring,
  teacher and trainer/activation boundaries, time/resource limits and output paths.
- [x] Execute stage commands through the existing cancellation-aware environment;
  pass data via private files, validate JSON/schema and preserve diagnostic results.
- [x] Enforce a rollout step bound, transition IDs and score coverage. Select only
  low-score windows for relabeling; reject missing/mismatched teacher results.
- [x] Train from the relabeled dataset, validate the produced model artifact and
  record its digest/identity. Activate/rebind it before the next rollout.
- [x] Persist iteration/model/harness/environment identity and enforce continuity
  across iterations and resume. Keep immutable prior iteration evidence.
- [x] Integrate a public CLI/pipeline path that uses the existing hub ownership.
  Replace the misleading prompt-only example with runnable configuration and
  explicit external trainer requirements.
- [x] Fail closed on subprocess errors, cancellation, malformed evidence, unchanged
  or missing model artifacts and mismatched environment continuity. Bound iterations
  and budgets; no online training is run implicitly by tests.
- [x] Run an actual local subprocess journey, review, and commit.

Training acceptance additionally requires the next rollout to consume the activated
checkpoint and live-refining harness, with observable action changes. Scoring uses
contextual transitions and explicit window/stride configuration. Teacher output
has a documented soft-target schema suitable for the configured trainer; the
objective and interpretation are recorded, not inferred from stage names. Initial
checkpoint provenance must attest warmup SFT/offline GRPO or explicitly identify a
supplied operator-pretrained checkpoint. Zero selected windows skip training.
Persist stage boundaries so resume never replays completed environment actions;
uncertain interrupted rollout requires explicit recovery evidence. Failed activation
keeps the previous usable checkpoint. Bound artifact sizes, reject cross-iteration
results and preserve immutable checkpoints. Exercise cancellation and failed-stage
resume through the public entry point.

## Task 3: Workflow/runtime repair

Files: `parser.lg`, `conditions.lg`, `handlers.lg`, `cli.lg` and existing parser,
parameters, cancellation, conditions and CLI test namespaces.

- [x] Add failing public tests for R01/R02/R09/R10/R24, including instant human gate.
- [x] Share explicit/implicit node construction, preserving promoted defaults.
- [x] Reject empty clauses around conjunctions.
- [x] Route timed/untimed tools through one owned execution boundary with exported
  parameters. An absent deadline must not disable cancellation.
- [x] Subscribe before submitting CLI work; retain the initial cursor and detach
  only after work/events settle. Cover run, resume and external-agent output.
- [x] Run impacted runtime and transport suites, review, and commit.

## Task 4: Provider protocol and reproducibility repair

Files: `llm.lg`, `test/attractor/llm_test.lg` and focused native wire tests.

- [x] Add failing tests for R04/R11/R12/R23/R25.
- [x] Preserve malformed Anthropic arguments as errors through dispatch.
- [x] Correct filename MIME inference and org/project header propagation.
- [x] Use native Responses named-choice shape; record the pinned-spec interpretation.
- [x] Isolate provider-registry fixtures without changing user configuration.
- [x] Run affected native adapter/stream/agent tests, review, and commit.

## Task 5: Extension and connector lifecycle repair

Files: `skill_eval.lg`, `mcp_client.lg`, `mcp.lg`, `providers.lg`,
`agents/codex.lg`, their existing tests.

- [x] Add failing roundtrip, bounded teardown, partial-admission rollback,
  pre-cancelled handshake and config-permission tests for R19–R22/R26.
- [x] Validate skill reports against the complete verdict policy.
- [x] Bound cleanup independently of an already-triggered operation abort.
- [x] Stage MCP admission or roll back registrations and close every acquired handle.
- [x] Observe cancellation/transport failure throughout Codex startup under one
  operation deadline.
- [x] Apply file privacy policy to every credential-bearing provider field.
- [x] Run focused tests, review, and commit.

## Task 6: Evidence convergence and integrated verification

- [x] Reconcile current user guides and annotated specs; add supersession pointers
  to relevant historical documents and repair confirmed stale project links.
- [x] Clarify legacy server support; do not remove an externally callable API
  silently. Keep current CLI evidence distinct from legacy server tests.
- [x] Record each audit finding as repaired or explicitly outstanding with evidence.
- [x] Run full deterministic suite, fresh public HTTP human-gate smoke and executable
  local co-learning journey; address failures rather than relying on old counts.
- [x] Obtain specification review, then Google-guideline quality review and fix
  actionable findings before final checkpoint.
- [x] Commit final docs/evidence references and report remaining external training
  dependencies and unrun live-provider/real-model performance validation plainly.

The context-foundations branch remains a separate integration decision. These
repairs must not silently merge it or claim its branch-only evidence for main.

## Final verification

At code checkpoint `23d0239`, the complete `lgx suite` passes 1,676 tests /
14,691 assertions with zero failures. Fresh build and seven-check public HTTP
question smoke pass. Optional co-learning has 12 deterministic tests / 44 assertions,
including a real local trainer process and changed next-rollout policy. Independent
specification, Google quality and documentation reviews completed. Live vendor
calls and real-model training performance were not run. Details and capability
limits remain in the audit's repair checkpoints and current harness usage guide.

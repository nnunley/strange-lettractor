# Interactive harness implementation plan

> Use subagent-driven-development, test-first implementation, specification review
> followed by Google code-quality review. Root owns Git commits on the existing
> working branch; one implementation worker at a time. User-created files stay
> untouched. Design: ../specs/2026-10-07-interactive-harness-design.md.

**Goal:** make the continual harness usable through an ongoing interactive session
and recover safely from the reported llama.cpp context overflow.

**Architecture:** extend console -> hub -> native agent; reuse ledger transactions,
agent queues and owned operations. Separate background planning from guarded
application only in interactive mode. Reuse existing context foundations where
appropriate without silently merging their branch.

**Stack:** let-go/lgx, native fixtures, existing nREPL/HTTP and console layers.

## Chunk 1: Interactive session ownership

Files: `src/attractor/{hub,agent,refiner,cli}.lg`,
`src/attractor/console/{input,session}.lg`; corresponding existing tests, plus
`test/attractor/interactive_harness_test.lg` only if needed for public journeys.

- [ ] Add failing deterministic tests for queued steering/follow-ups and the
  completion-admission race. Preserve ordinary hub busy rejection by default.
- [ ] Implement explicit queued submission through existing agent queues, with
  acceptance and drain semantics that cannot drop a late message. Queued responses
  share the aggregate turn ID/result and say queued=true; test final-drain races.
- [ ] Add tests for background refinement planning, guarded application and
  cancel/close while planning or waiting. Split plan/apply with owned lifecycle;
  retain batch semantics. Reject stale plans if the ledger changed during planning.
- [ ] Wire `/followup`, `/harness`, `/refine`, render lifecycle results, and expose
  trusted CLI startup options. Allocate durable paths and reject conflicting
  live explicit-path owners. Verify local and attached clients.
- [ ] Run affected namespaces through `test/runner.lg --deadline-ms 180000` with
  `LGX_LG=/opt/homebrew/bin/lg`, then specification and quality review; fix findings
  and commit the verified increment.

## Chunk 2: Context overflow closure

Files to be pinned by diagnosis: agent request admission/compaction, provider
error mapping and model-limit resolution in existing `agent.lg`, `llm.lg`,
`profiles.lg`/provider files, and focused context contract tests.

- [ ] Diagnose current request-limit/compaction behavior and the exact structured
  llama.cpp error. Record evidence before selecting a repair.
- [ ] Add failing tests using `exceed_context_size_error`, `n_prompt_tokens=134031`,
  `n_ctx=131072`, realistic long histories and tool-call/result pairs.
- [ ] Implement complete-request budget admission with response reserve and safe
  history reduction, plus bounded classified-overflow recovery where needed.
  Fail clearly if immutable/current input cannot fit. No generic invalid-request
  retry and no blind truncation of paired tool histories.
  Preserve the full transcript and lifetime accounting separately from the reduced
  model context so compaction cannot erase evidence or replenish usage budgets.
- [ ] Verify native/provider/context suites, obtain specification and Google
  quality review, resolve findings and commit.

## Chunk 3: User journey and evidence

- [ ] Update existing README, hub and harness guides with exact interactive
  commands, queues, refinement behavior, cancellation and persistence limits.
- [ ] Run end-to-end deterministic interactive journey and complete suite; build
  executable. No live endpoint calls or trainer requirements.
- [ ] Record limitations and final results in this plan; commit documentation.

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

**Verification runtime:** final checks use
`LGX_LG=/Users/ndn/development/let-go/bin/lg`, as requested on October 8.
Earlier October 7 counts below were obtained with `/opt/homebrew/bin/lg`.

## Chunk 1: Interactive session ownership

Files: `src/attractor/{hub,agent,refiner,cli}.lg`,
`src/attractor/console/{input,session}.lg`; corresponding existing tests, plus
`test/attractor/interactive_harness_test.lg` only if needed for public journeys.

- [x] Add failing deterministic tests for queued steering/follow-ups and the
  completion-admission race. Preserve ordinary hub busy rejection by default.
- [x] Implement explicit queued submission through existing agent queues, with
  acceptance and drain semantics that cannot drop a late message. Queued responses
  share the aggregate turn ID/result and say queued=true; test final-drain races.
- [x] Add tests for background refinement planning, guarded application and
  cancel/close while planning or waiting. Split plan/apply with owned lifecycle;
  retain batch semantics. Reject stale plans if the ledger changed during planning.
- [x] Wire `/followup`, `/harness`, `/refine`, render lifecycle results, and expose
  trusted CLI startup options. Allocate durable paths and reject conflicting
  live explicit-path owners. Verify local and attached clients.
- [x] Run affected namespaces through `test/runner.lg --deadline-ms 180000` with
  `LGX_LG=/opt/homebrew/bin/lg`, then specification and quality review; fix findings
  and commit the verified increment.

Verified checkpoint: `93a860b`. Worker: 92 tests / 595 assertions pass.
Root independent final path/interaction check: 35 tests / 222 assertions pass;
root runtime-discovery-inclusive run: 50 tests / 316 assertions pass. Specification
and Google quality reviews approved after fixing symlink-plus-parent ledger paths.
Counts overlap and must not be added. Full public tool/environment continuity
journey remains in Chunk 3.

## Chunk 2: Context overflow closure

Files: `src/attractor/agent.lg`, `llm.lg`, one focused
`context_management.lg` module if needed to keep projection/budget logic out of
the agent loop, and existing provider/session/context tests plus a focused
compaction contract namespace. CLI/console/hub may expose `/context` and `/compact`
through the same trusted session operations.

- [x] Diagnose current request-limit/compaction behavior and the exact structured
  llama.cpp error. Record evidence before selecting a repair.
- [x] Add failing tests using `exceed_context_size_error`, `n_prompt_tokens=134031`,
  `n_ctx=131072`, realistic long histories and tool-call/result pairs.
- [x] Implement complete-request budget admission with response reserve and safe
  history reduction, plus bounded classified-overflow recovery where needed.
  Fail clearly if immutable/current input cannot fit. No generic invalid-request
  retry and no blind truncation of paired tool histories.
  Preserve the full transcript and lifetime accounting separately from the reduced
  model context so compaction cannot erase evidence or replenish usage budgets.
  Use bounded model-backed rolling summaries with prior summary, goals, constraints,
  completed operations and pending work; failed/empty/oversized summary leaves the
  projection unchanged. No silent truncation fallback. Summary inputs must also
  fit, with a bounded call count; oversized individual exchanges fail recoverably.
  Counts remain explicitly estimated unless an actual provider-rendered count is
  available. Summary usage counts toward spend, not agent-step or turn limits.
  Learn the validated server `n_ctx` for overflow recovery despite stale larger
  discovery. Automatic generation retry is permitted only before visible partial
  output; otherwise report a recoverable failure. Regression fixtures must keep
  production admission enabled by default, even with mock/injected clients.
- [x] Verify native/provider/context suites, obtain specification and Google
  quality review, resolve findings and commit.

Verified checkpoint: `41fb759`. Final focused requested-runtime run: 61 tests /
395 assertions pass. Independent specification review passes 39 tests / 215
assertions after fixing accepted native queues stranded by recoverable errors.
Google quality review approved after correcting start-only stream recovery and
native provider-option overrides. Hub shutdown now settles unresolved aggregates
after worker join. The baseline timeout fixture also assumed cancelled sleep would
resume execution; `eb3de5e` replaces that assumption with an explicit late-handle
handoff, and all 85 LLM tests / 525 assertions pass. Counts overlap.

## Chunk 3: User journey and evidence

- [x] Update existing README, hub and harness guides with exact interactive
  commands, queues, refinement behavior, cancellation and persistence limits.
- [x] Run end-to-end deterministic interactive journey and complete suite; build
  executable. No live endpoint calls or trainer requirements.
- [x] Record limitations and final results in this plan; commit documentation.

## Requested-runtime verification follow-up

The first complete run with the requested local runtime finishes: 1,713 tests /
14,887 assertions, 45 failed assertions. Its snapshot predates the repaired LLM
fixture. Remaining failures concern parallel cancellation/join behavior, two
fan-in descendant-cleanup fixtures, Codex startup cancellation, steering history
classification and the nREPL queued acknowledgment shape. These require explicit
adjudication before claiming final integrated success. Evidence:
`evidence/interactive-harness-2026-10-07/full-suite-before-cancellation-migration.log`.

- [x] Separate runtime cancellation assumptions from production defects, repair
  the proven cases without weakening cleanup/ownership assertions, and review.
- [x] Rerun affected contracts and then the full suite with the requested runtime.

Migration checkpoint: `636ea99`, approved by specification and Google quality
review. The affected groups pass 60 tests / 541 assertions. Broader regression checks pass
93 tests / 598 assertions, and steering/context/hub checks pass 63 tests / 402
assertions. Independent specification review passes 77 tests / 556 assertions.
Typed cancellation is normalized only at actual cancellation boundaries;
fixtures retain joined-finalization, error identity and late-acquisition checks.
Steering retains its history type through both native and recovered hub queues.

## Final integrated result

At `636ea99`, `LGX_LG=/Users/ndn/development/let-go/bin/lg lgx suite` exits 0:
**1,713 tests / 14,888 assertions / zero failures**. The runtime reports
`lg dev (0cfd343)`. `lgx rebuild` succeeds; the compiled offline console completes
two turns in one session, exposes `/context` and `/harness`, persists its ledger
and shuts down cleanly. Evidence: `full-suite.log`, `build.log`,
`compiled-console-transcript.log` and `console_smoke.py` in the iteration evidence
directory. Use `rebuild` on macOS: overwriting an existing executable in place
produced the already documented exit-137 behavior.

No live model or training run was performed. Token admission remains heuristic;
oversized irreducible exchanges fail recoverably, full transcripts remain
in-memory, and provider-observed capacity is retained for the current turn.
The ordinary interactive harness requires no trainer. User-owned `my-harness.dot`
and `my-harness.edn` remain untouched and untracked.

# Qwen context retry implementation plan

Approved design: first retry with relevant source locations and mechanical
failure diagnostics, without suggesting an implementation. Add bounded search
only if this context-only retry stalls. No changed acceptance criteria, model
settings, request budget, sandbox policy or candidate-authored Codex fixes.

**Goal:** Determine whether better navigation context permits a useful Qwen edit.

**Architecture:** Update only the quota task prompt in `tasks.edn`; use the
existing let-go runner and its 240-second outer wrapper. Start from the unchanged
quota candidate at 52d928d. Retain old artifacts and use a fresh output directory.

**Tech stack:** let-go, EDN, existing Attractor DOT runner, local llama.cpp.

## Steps

- [x] Independently review this scoped design/plan.
- [x] Verify candidate HEAD/cleanliness and local model availability.
- [x] Record the current eight-case quota acceptance failure and source locations.
- [x] Append those locations and diagnostics to the quota prompt only.
- [x] Verify task data loads and the prompt contains no proposed patch.
- [x] Run one context-only quota attempt with existing limits and gates.
- [x] Record outcome, tool activity, complete changed paths and patch evidence.
- [x] If it passes, independently review the patch and run impacted tests before
  integration. If it stalls, implement/test a bounded literal-search tool confined
  to existing readable files before a separately labelled second-stage trial.
- [x] Commit and push scoped evidence, without claiming full-goal completion.

The deprecated sandbox-exec usage remains temporary pilot infrastructure; this
experiment does not expand its role. Private notes remain excluded.

## Context-only outcome

The single retry passed in 7 requests / 33,097 ms: 8/8 fixed acceptance checks,
1 regression test / 24 assertions, unchanged verifier hashes and no limit reached.
Qwen made the production edit and wrote the test; Codex supplied navigation and
diagnostics but no implementation. Only the two permitted candidate paths changed.

Independent spec and quality review approved the patch. The generated regression
test fails against the original production source (18 pass, 6 fail) and the
candidate's combined LLM tests pass (84 tests, 519 assertions). The full suite
passes with development tools on PATH: 604 tests, 5,502 assertions, zero failures.
An earlier system-only-PATH full run reported 604 tests, 5,499 assertions and
two failures; its truncated output did not retain failure details, so this record
does not claim their exact cause was established. No code changed between runs.

`bench/implementer_pilot/context_retry_results.edn` records exact patch/test
contents, mechanical evidence, actual usage, and local raw-artifact paths.
The search-tool stage is not triggered: context-only succeeded. This single
success supports trying similarly small, well-located tasks, not broad autonomous
implementation or an estimated success rate.

The reviewed fix was fast-forwarded onto main and pushed as `699f26b`. Main's
tree matches the fully tested candidate tree. Harness context/results are kept
on `qwen-implementer-pilot`; all candidate worktrees are retained.

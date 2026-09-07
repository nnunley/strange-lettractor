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

- [ ] Independently review this scoped design/plan.
- [ ] Verify candidate HEAD/cleanliness and local model availability.
- [ ] Record the current eight-case quota acceptance failure and source locations.
- [ ] Append those locations and diagnostics to the quota prompt only.
- [ ] Verify task data loads and the prompt contains no proposed patch.
- [ ] Run one context-only quota attempt with existing limits and gates.
- [ ] Record outcome, tool activity, complete changed paths and patch evidence.
- [ ] If it passes, independently review the patch and run impacted tests before
  integration. If it stalls, implement/test a bounded literal-search tool confined
  to existing readable files before a separately labelled second-stage trial.
- [ ] Commit and push scoped evidence, without claiming full-goal completion.

The deprecated sandbox-exec usage remains temporary pilot infrastructure; this
experiment does not expand its role. Private notes remain excluded.

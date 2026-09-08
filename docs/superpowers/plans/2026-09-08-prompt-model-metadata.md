# Prompt model metadata implementation plan

> **For agentic workers:** Use subagent-driven-development with the project's
> actual Claude connector for bounded implementation; main owns mechanical tests
> and integration. Preserve the user's preference against repeated review loops.

**Goal:** Fix coding-agent spec section 6.3 display-name and knowledge-cutoff
omissions without changing model routing or fabricating provider metadata.

**Architecture:** Resolve optional trusted profile `:display_name` and
`:knowledge_cutoff` at session creation, falling back to matching-provider catalog
metadata. Non-string/blank metadata is absent. Unknown display name falls back to
the actual model ID; unavailable cutoff is explicitly `unknown`. Keep the existing
snapshot `:model` and request model unchanged; add display/cutoff snapshot fields.
No catalog facts are invented or fetched during sessions. An unknown value is an
honest fallback, not evidence that the catalog metadata requirement is complete.

**Tech Stack:** let-go; existing profiles, advisory model catalog and session API.

## Chunk 1: regression and fix

- [x] Add `test/attractor/prompt_metadata_test.lg`: actual two-turn request capture
  checks stable git/environment block, catalog display name and explicit cutoff;
  profile overrides, alias lookup, unknown model and mismatched-provider fallback;
  request model identity remains unchanged. Use controlled environment inspection,
  not live shell/model calls. Close every session in finally.
- [x] Add `dev/prompt_metadata_tests.lg` following existing focused runner pattern.
  Run `/Users/ndn/development/let-go/lg -source-paths src:test dev/prompt_metadata_tests.lg run`;
  require intended metadata assertion failures, no fixture errors.
- [x] In `src/attractor/agent.lg` only, pass profile into environment snapshot,
  resolve nonblank strings using existing `llm/get-model-info`, constrain catalog
  fallback to the profile provider, keep raw `:model`, and render new fields.
  Conceptually: display = profile display OR catalog display OR raw model;
  cutoff = profile cutoff OR catalog cutoff OR `unknown`.
- [x] Rerun focused tests; inspect diff for unrelated changes. Bundle focused
  runner with `lg -source-paths src:test -b <temporary-path> dev/prompt_metadata_tests.lg`
  and run outside checkout. Run full local-lg `lgx test`, build and help.
- [x] Record exact results and limits in conformance evidence, commit only named
  files, fast-forward root and push public main/console. Never touch private notes.

# Stream Segment Completion Implementation Plan

> Use subagent-driven-development with test-first implementation and independent spec and quality review.

**Goal:** Fulfil pinned unified-LLM §3.14 typed completion for text and reasoning segments across native and compatible adapters.

**Architecture:** Keep provider-specific stream normalization in `src/attractor/llm.lg`. End events carry `:text` or `:reasoning`, never replay their value as a delta. Reuse indexed Anthropic blocks and Gemini/compatible buffers. OpenAI needs per-segment accumulation and completion deduplication, using content indices to avoid mixing multiple parts of one item. Preserve raw events and final response semantics. Redacted thinking remains opaque.

**Tech stack:** Local Go-based let-go, existing JSON/SSE transport seam, clojure.test. No JVM APIs, dependencies, live models, or runtime edits.

## Implementation task

- [x] Add `test/attractor/stream_completion_test.lg` with public `llm/stream` offline SSE cases. Assert completed values, exact Unicode/whitespace, empty segments, interleaved segments, duplicate completion, done-only and delta-only fallback, raw metadata, and final response/tool/usage preservation. Cover Anthropic redacted thinking without inventing plaintext. Cover compatible text as well as native text/reasoning.
- [x] Run focused tests and observe assertion failures before changing production code:
  `/Users/ndn/development/let-go/lg -source-paths src:test -e '(require (quote attractor.stream-completion-test)) (clojure.test/run-tests) (os/exit (if clojure.test/*test-result* 0 1))'`
- [x] Implement missing end values and required segment isolation. Preserve IDs for unindexed/single-index-zero streams when possible, with collision-free IDs for additional indexed segments. All applicable OpenAI done paths must use the same segment state and suppress duplicate completion. Prefer explicit native done text when supplied (including empty), otherwise accumulated deltas. Do not broaden this into transport cancellation or whole-provider parity.
- [x] Re-run focused tests, existing `attractor.llm-test` and `attractor.qwen-reasoning-test` together; fix regressions.
- [x] Independent spec review, then quality review; resolve findings.
- [x] Parent runs full `env PATH="/Users/ndn/development/let-go:$PATH" lgx test`, build, standalone bundled focused tests, and the original audit probe. Only one full suite at a time; do not edit tests during it.
- [ ] Update audit evidence, commit scoped files, integrate and push only after verification. Preserve all other worktrees and private `docs/notes.md`.

## Baseline and limitations

Baseline `5e811b1`: existing LLM suite 83 tests / 494 assertions / zero failures. The root offline probe reports six missing native completion fields. Native HTTP/live model coverage remains separate. This task is not full Attractor completion.

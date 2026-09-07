# OpenAI-compatible streaming reasoning

The local-model adapter (currently named `ollama`, also used with llama.cpp)
preserved `reasoning_content` in non-streaming replies but discarded the same
field in streaming deltas. A deterministic SSE probe containing `Think` followed
by answer text produced no reasoning events and a nil final reasoning value.

The compatible streaming adapter now emits reasoning start/delta/end events for
string values and accumulates exact reasoning into the final response. Empty
strings are retained; absent, null and non-string values are ignored, matching
the existing non-streaming normalization. Reasoning remains separate from visible
answer text and tool-call arguments. Errors suppress subsequent events and do
not fabricate a successful finish.

The reasoning-end event carries the final accumulated `:reasoning` value;
`:reasoning_delta` remains exclusive to incremental events. This follows the
typed-completion clause in pinned unified-LLM spec §3.14 without making a consumer
accumulate the same text twice.

## Mechanical evidence (2026-09-07)

- Missing-reasoning regression: 18 failed assertions, zero test errors before
  the implementation change.
- End-event value regression: three failed assertions before adding that field.
- Final focused suite: seven tests, 57 assertions, zero failures/errors.
- Combined LLM and focused contracts: 90 tests, 551 assertions, zero failures.
- A standalone bundled entrypoint explicitly requiring the adapter and focused
  test namespace passed the same seven tests / 57 assertions outside the repo.
  This verifies packaged bytecode, not native Go AOT lowering.
- Final worktree suite: 577 tests, 4,780 assertions, zero failures.

Run the focused suite with the local runtime:

```sh
/Users/ndn/development/let-go/lg -source-paths src:test -e '(require (quote attractor.qwen-reasoning-test)) (clojure.test/run-tests) (os/exit (if clojure.test/*test-result* 0 1))'
```

The tests exercise low-level streaming, a configured client, the stream
accumulator, and high-level response/text-stream access. They include mixed
reasoning/text/tool chunks, usage-only trailing chunks and errors followed by
late data. The native-provider LLM regression suite is retained unchanged.

## Scope and remaining evidence

This is a local normalization fix, not a live-model or subscription test. No
model calls were made and no let-go runtime changes were required. Native OpenAI
continues using Responses, Anthropic Messages and Gemini generateContent; this
does not replace those adapters with a compatibility API.

Reasoning-history replay and thinking-content-part representation are unchanged.
Repeated `[DONE]` handling and the corresponding accumulated-value fields on
other adapters' segment-end events remain separate streaming audit work. Do not
infer full streaming conformance or native-provider parity from this fix.

# Streaming HTTP error-body repair

Scope: pinned unified LLM §§6.1–6.4 require provider error fields and retry
classification. Current native streaming HTTP error bodies are readers, but
`provider-error` stringifies the reader, losing JSON codes, quota classification
and raw response data. Repair the native/compatible streaming boundary without
changing the public pure string/map error normalizer or success-event behavior.

1. Add `test/attractor/stream_http_error_test.lg` exercising public stream/client
   APIs with reader error bodies for OpenAI, Anthropic, Gemini and compatible.
   Show RED: quota429 should be nonretryable with code/raw; auth401 no retry;
   transient429 honors Retry-After and bounded attempts. Preserve string/map
   injected transports. Check body closure (also on parse/read failure).
   Include a held error body after headers: high-level abort must close/unblock
   reading, raise `:abort`, avoid retry, and settle cleanup. Test abort racing
   closer registration and idempotent repeated closure; ordinary read errors
   preserve HTTP classification but cancellation stays distinct.
2. In `src/attractor/llm.lg`, introduce a small streaming HTTP error helper that
   registers a reader's idempotent closer before consuming it, reads actual text,
   normalizes the error and closes in finally. Wire all four streaming adapters.
   Do not change successful SSE behavior. Preserve status classification if
   body decoding fails; cancellation must still be able to close a held body.
3. Parent validates real socket error responses through existing native HTTP,
   checking requests counted by the server. No model endpoint or real key.
4. Independent spec then quality review. Run focused+existing LLM/Qwen tests,
   full suite once files freeze, build and standalone bundle; commit/push scoped
   changes after verification. Preserve all other worktrees/private notes.

Use local Go-based let-go, not JVM APIs. Runtime #816 still limits cancellation
before headers; this repair must not claim to solve it or full transport parity.
Native connect/request/read deadlines remain separate work. Reading an error
body must not make high-level cancellation unable to close the known body.

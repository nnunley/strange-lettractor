# Terminal streaming errors

The unified LLM specification (§§3.13 and 6.6) requires typed SDK errors and no
automatic retry after partial delivery. This change makes explicit provider
error events terminal across OpenAI Responses, Anthropic Messages, native Gemini,
and the separate OpenAI-compatible adapter.

Before this change, Anthropic could emit `:error` followed by `:finish`, Gemini
ignored native error frames, and the compatible adapter suppressed late events
but still consumed the wire tail. OpenAI failed responses also needed their
nested `response.error` normalized.

## Contract

- Emit one terminal `:error`, containing an SDK exception under `:error` and the
  original provider event under `:raw`.
- Retain provider/category/code/retryability and actual available status data.
  Gemini's numeric native HTTP error code is retained as status; other numeric
  provider codes are not assumed to be HTTP statuses. SDK error codes are strings.
- Close an owned native body once without realizing the next frame. Apply the
  same terminal boundary to custom adapters in high-level streaming.
- Preserve delivered output in `:text_stream` and `:partial_response`; after
  failure, calling `:response` throws the retained error instead of returning a
  partial response as successful completion. Accessors do not implicitly drain
  the stream.
- Never process later text, reset, tool, or finish events, execute later tools,
  or retry the failed stream. An error may be intrinsically retryable without
  this already-started stream being retried.

## Mechanical evidence

`test/attractor/stream_terminal_error_test.lg` covers native low-level,
configured-client, and high-level first/partial errors, typed classifications,
custom adapters, poisoned lazy tails, close idempotence, and final versus partial
responses. Corrected initial fixtures produced 197 failing assertions before
implementation; additional classification assertions produced 18 failures before
their fix. Final focused result: **7 tests, 346 assertions, no failures/errors**.
The impacted LLM, Qwen reasoning, segment completion, HTTP-error, and terminal
suites passed **116 tests / 1,249 assertions**.

The final feature-worktree default suite passed **603 tests / 5,478 assertions,
zero failures**, exit 0. `lgx build` and `bin/attractor help` exited 0. The focused
runner was compiled with local let-go into a standalone bundle and run from
`/tmp`: **7 tests / 346 assertions**, zero failures/errors. This exercises packaged
bytecode, not native Go AOT lowering. Independent spec and quality reviews passed.

Real HTTP verification uses the bounded, loopback-only fixture:

```sh
go run test/probes/http_error_server.go
# In another terminal, substitute its printed loopback URL:
/Users/ndn/development/let-go/lg -source-paths src \
  test/probes/stream_terminal_http_check.lg http://127.0.0.1:PORT
```

All **four cases passed**. Each provider sent `partial`, an error, then late text
while holding the HTTP response open. Each client completed with one typed error,
retained `partial` in both output views, raised the same error data from
`:response`, and made exactly one request with no retry delay. The server observed
each connection's cancellation and zero held handlers before explicit checker
cleanup; cumulative cancellation counts were 1, 2, 3, and 4. No live model calls.
An initial checker run used the wrong partial-response field (`:text` rather than
`[:message :text]`); it was corrected before this passing run and is not RED
implementation evidence.

The existing `test/probes/http_error_check.lg` was also rerun against the extended
fixture: all **13 HTTP-error cases passed**, including the held-body abort case.

## Remaining boundaries

This does not establish generic before-headers HTTP cancellation, worker or
monitor join-before-return, default native deadlines, all provider release/live
parity, or duplicate non-error event handling. See
[the HTTP cancellation evidence](let-go-http-cancellation.md) and upstream
[#816](https://github.com/nooga/let-go/issues/816).

The fixture encoder temporarily keywordizes its fixed string keys because of
confirmed let-go [#817](https://github.com/nooga/let-go/issues/817). This is only a
test-fixture workaround, not an application-wide JSON key conversion. Internal
application serialization remains `.edn`.

# Streaming HTTP errors

Native streaming transports return a reader even for a non-200 response. At
baseline `25aa00a`, the adapters passed that reader to the string/map error
normalizer. Its object representation replaced the JSON body, losing `raw` and
`error_code`; a 429 quota error became a retryable rate-limit error.

The four streaming adapters now consume error-body readers before normalization
and close them in `finally`. An idempotent closer is registered before reading,
including the race where cancellation has already happened. String/map/nil
injected transport bodies retain their old path. Ordinary body-read failures
retain status-based classification rather than turning a 401 into a generic
retryable exception. Successful SSE event handling is unchanged.
The controlled call also rechecks cancellation after its worker result arrives,
so an interrupted read cannot race past the pre-wait check and surface as an
authentication/rate-limit error instead of an abort.

## Evidence

The new `attractor.stream-http-error-test` suite has eight tests / 208 assertions.
Before implementation, the initial five tests had 40 failures; the expanded
seven-test suite produced 60 failures against baseline production code. Review
then identified the post-wait cancellation race; its deterministic gated test
produced four failures before the fix. Final focused execution passes all 208
assertions, and the combined LLM/Qwen/error suite passes 98 tests / 759 assertions.
The same 8/208 tests pass as a standalone bundle executed outside the checkout.
This is packaged bytecode evidence, not native Go AOT lowering. `lgx build` and
the rebuilt CLI's `help` command also exit 0. Spec and code-quality reviews approve.
Final worktree full suite: 596 tests, 5,131 assertions, zero failures, exit 0.
Fresh main verification after integrating `9543aaa` passes the same 596/5,131/0;
the rebuilt main CLI's `help` also exits 0.

Real socket checks use `dev/http_error_server.go` and `dev/http_error_check.lg`:

```sh
go run dev/http_error_server.go
# In another shell, replace URL with the loopback address it prints:
/Users/ndn/development/let-go/lg -source-paths src dev/http_error_check.lg URL
```

All 13 cases pass, exit 0, with independent server request counts:

- OpenAI, Anthropic, Gemini and compatible: quota429 and authentication401 each
  make one request and retain raw JSON/code with `retryable=false`.
- Each adapter's rate-limit429 makes exactly three requests. The injected sleep
  callback receives two 0.02-second delays from Retry-After. This proves delay
  selection and retry bounds, not elapsed wall-clock backoff scheduling.
- An OpenAI 401 whose body stalls after headers returns `:abort`, makes one
  request, closes its connection (server context canceled), and settles all
  workers in its scope within a one-second observation window before release.

The first held-body run sampled a transient live worker immediately after server
cancellation. The corrected checker waits boundedly for worker settlement. It
does **not** prove the worker is joined before the public caller returns.
The fixture drains request bodies before readiness, binds only loopback, and
has 10-second held-response / 60-second server safety bounds. Successful runs
shut it down explicitly; observed fixture processes exit 0. No real API keys or
model endpoint are involved. Fixture Go code is infrastructure, not production.

## Remaining transport requirements

[let-go #816](let-go-http-cancellation.md) remains: requests blocked before
headers do not inherit scope cancellation. Attractor still needs joined worker
and stream-monitor ownership, native connect/request/read deadlines, stalled
success-body coverage, and the broader provider/session error matrix. An error
body can still block without caller cancellation/timeout; this change does not
provide the missing native default read deadline. It repairs error normalization
and known-body closure, not full ULLM-CANCEL-01/ULLM-ERROR-01 conformance.

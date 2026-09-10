# Session provider errors and context recovery

This component implements coding-agent-loop §2.8, §9.11 and Appendix B's
distinction between a failed input and an unrecoverable session failure.

Typed SDK errors carried by stream events retain their category, message and
provider fields. Untyped custom events retain the existing compatibility wrapper.
Authentication remains fatal. Context overflow closes the current stream, emits
a warning and processing-end event, and returns the session to idle without
destroying history, queued inputs, environment, children or the abort controller.
The failed input throws its original error; it does not fabricate successful
output, compact history, retry unchanged input, or consume queued follow-ups.
Warning-triggered abort/close must not reopen a session or emit post-terminal
events. A later explicit input can succeed.

## Mechanical verification

Run from the checkout with `/Users/ndn/development/let-go/lg` (tested dev bdd8268):

```sh
/Users/ndn/development/let-go/lg -source-paths src:test \
  test/runner.lg attractor.session-error-contract-test
/Users/ndn/development/let-go/lg -source-paths src:test \
  test/runner.lg attractor.session-error-http-fixture-test
/Users/ndn/development/let-go/lg -source-paths src:test \
  test/attractor/session_error_http_bounded_test.lg
/Users/ndn/development/let-go/lg -source-paths src:test \
  test/probes/session_error_http_bounded.lg run
```

- Core baseline RED: 5 tests, 113 passing / 64 failing assertions on main 699f26b.
- Core candidate GREEN: 5 tests / 177 assertions; paired spec and quality reviews.
- Impacted agent/loop/stream/error tests: 62 tests / 949 assertions, zero failures.
- Fixture contracts: 1 test / 26 assertions. Outer-command validation: 1 / 7.
- Native loopback HTTP: 8 cases, all passing, through public sessions and real
  OpenAI, Anthropic, Gemini and OpenAI-compatible adapters; no custom transport
  callbacks or live model calls. 401 makes one request and closes; 413 makes one
  request, warns and stays idle, then a new input succeeds on request two.
- Owned fixture cleanup settled with exit 130 and cancellation recorded.
- Standalone bundled core tests passed 5 / 177 from `/tmp`; `lgx build` and
  built CLI `help` passed. These are bundle/build checks, not native-Go AOT proof.

Final default suite: **609 tests / 5,679 assertions / zero failures**, exit 0.
The fresh main sentinel baseline was 604 tests / 5,502 assertions / zero failures.
The reusable bounded HTTP wrapper independently passed all 8 cases in 2,208 ms;
its checker exited 0 without timing out. See `session-error-contract-evidence.edn`.

## Execution boundary and residuals

All new fixture/checker source is let-go. The checker owns a loopback-only server
process; readiness requires its unique token before provider requests are sent.
The server process has a 30-second lifetime and is canceled/joined in `finally`.
Use the outer wrapper above: it bounds the checker at 60 seconds, with the
execution environment's termination grace, and cleans up before returning status.
Native HTTP's per-request cancellation/deadlines remain unresolved (#816).

Responses contain complete, buffered SSE bodies. This proves provider decoding
and session recovery, not incremental delivery, flushing, held-body cancellation,
full graceful-shutdown order, general retry behavior or live-provider parity.
The existing Go fixtures are not extended or used by these checks. A general
let-go streaming server and native AOT release proof remain separate work.

# Agent session error contract implementation plan

> **For agentic workers:** Use subagent-driven-development and test-driven-development.

**Goal:** Preserve typed provider failures through agent sessions and allow the
session to remain usable after a context-length failure, as required by coding
agent loop §2.8, §9.11, and Appendix B.

**Architecture:** Keep provider classification in the unified LLM layer. Preserve
already typed stream errors in `stream-response!`; retain the legacy wrapper for
untyped custom error events. Handle context-length separately at the session
input boundary, without fabricating a completed assistant turn or retrying an
unchanged request. Keep native let-go lifecycle locks and stream ownership.

**Tech stack:** let-go throughout, including test servers and fixtures; native
supervisor primitives, EDN event data, native provider JSON/SSE transport. Go may
be generated through AOT/gogen, but must not be authored as application or fixture
source. No JVM dependencies or local runtime edits.

## Design and alternatives

Current public repro: both complete and stream context-length failures close the
session. Stream events additionally replace `:authentication`/`:context-length`
with `:provider-stream`; the typed cause survives only as a nested exception.
The common catch unconditionally calls `close-session-after-error!`.

Merely preserving the exception fixes classification but leaves the specified
context-overflow lifecycle wrong. Automatically retrying overflow is also wrong:
the request has not changed, and the spec marks the failure non-retryable. The
selected approach preserves typed failures and distinguishes a failed input from
a permanently failed session.

For context-length, emit `:warning` with `:category :context-length`, retain the
user/history and any already delivered text events, close the current stream,
leave environment/subagents and the abort controller usable, return to `:idle`,
and emit `:processing_end`. Throw the original error to the caller for this input:
the existing string-returning API has no failure result variant, and returning an
empty/partial string would wrongly mark subagent/backend work successful. This is
a failed input, not a closed session. A subsequent explicit input must work. Do
not append an assistant turn, fake text completion, execute incomplete tools,
truncate history, retry, or automatically consume queued followups on failure.
Queued messages remain available for a later processing cycle.

For authentication and other fatal provider errors, preserve existing shutdown
behavior and one final `:session_end`, but retain the SDK category and fields in
the thrown error. Keep error/warning events serializable: category and message
are sufficient; do not place exception objects in event records. An abort/close
that races with warning delivery must never be overwritten by an idle transition
or receive events after `:session_end`.

Initial-connection retries, default deadlines, native cancellation joins (#816),
complete provider release parity, and generic session shutdown ordering are
separate pending requirements; this slice must not claim they are solved.

## Chunk 1: Typed failures and recoverable input overflow

Files: modify `src/attractor/agent.lg`; create
`test/attractor/session_error_contract_test.lg` and
`dev/session_error_contract_tests.lg` (standalone focused/bundle runner).

- [x] Add RED public tests for typed stream auth and context failures, plus
  complete_fn and thrown-stream context failures. Assert original SDK data,
  exact warning/error/processing/session-end order, stream close exactly once,
  no fake assistant history or tool execution, and no retry.
- [x] Cover first-event and post-partial failures, unchanged user/history and
  queue preservation, then a successful second `process-input!` on the same
  context-overflow session. Verify environment cleanup/abort is not triggered
  until explicit close. Authentication must close immediately and reject input.
- [x] Add callback-triggered abort/close during the context warning: no reopened
  session, no duplicate session end or post-terminal events.
- [x] Run `/Users/ndn/development/let-go/lg -source-paths src:test
  dev/session_error_contract_tests.lg run`; record expected lifecycle/category
  assertion failures before production changes.
- [x] In `stream-response!`, throw an error unchanged when its `ex-data` has an
  SDK category; keep the existing untyped custom-event wrapper otherwise.
- [x] Introduce a focused context-failure handling branch at the input boundary:
  warning, guarded idle transition, processing end, rethrow retained failure.
  Keep other error handling intact and avoid a broad loop rewrite.
- [x] Rerun the focused tests and impacted agent, stream, lifecycle, subagent,
  tool-loop, and timeout tests. Expected: zero failures/errors.

## Chunk 2: Real HTTP and delivery evidence

Parent owns `dev/session_error_http_check.lg`, the let-go-authored fixture server,
and `docs/session-error-contract.md`. Do not extend the handwritten Go server;
replace its use with let-go source, using AOT/gogen if appropriate. Report concrete
tooling gaps instead of silently falling back to handwritten Go.

- [x] Add a bounded loopback checker through public agent sessions and configured
  native clients. All four adapters: HTTP authentication fails once and closes
  the session; HTTP context overflow fails once, warns without session shutdown,
  then a successful response to a new input proves continued usability. No live
  model calls; explicitly close every session and shut down the fixture.
- [x] Independently review specification compliance, then code quality/evidence.
- [x] Freeze code/tests; run `env PATH="/Users/ndn/development/let-go:$PATH" lgx test`
  and `lgx build`, CLI help, and the focused standalone bundle from `/tmp`.
- [x] Record concrete counts/commands and remaining gaps; update CAL-ERROR-01
  without marking broader session/retry conformance complete. Commit scoped
  changes, fast-forward main, verify integration, and push public refs. Retain
  `.worktrees`; never read or publish private `docs/notes.md`.

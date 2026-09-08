# Codex App-server Transport Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove bounded duplex app-server initialization from let-go, without requesting a model turn.

**Architecture:** One owned subprocess, native let-go supervised workers, and a correlated JSON-RPC client. This is slice 1 of the [approved orchestration design](../specs/2026-09-06-codex-app-server-design.md); backend selection, model turns, and mixed-agent workflows are deliberately later slices.

**Tech Stack:** Local let-go >=1.12.2, existing `os/exec` method interop, `io`, native supervisor primitives, JSON only on the Codex wire, EDN for evidence.

---

## Chunk 1: Duplex lifecycle and initialization

Work in `.worktrees/codex-app-server`. Do not modify the user-owned let-go checkout or private `docs/notes.md`. Baseline on 2026-09-06: `lgx test` with local let-go passed 567 tests / 4710 assertions. The `/bin/cat` duplex probe in the design also passed. Those results do not prove the code below exists.

### Task 1: Pin wire assumptions and add a deterministic fake child

**Files:**
- Create `test/fixtures/codex_app_server.lg`: controllable child process, no network/models.
- Create `test/attractor/codex_transport_test.lg`: framing and lifecycle contracts.
- Create `docs/codex-app-server.md`: installed-version protocol notes and opt-in probe instructions.

- [ ] Record `codex --version`. Generate schemas into a fresh `mktemp -d` directory with `codex app-server generate-json-schema --out <directory>`. Inspect initialize request/result, initialized notification, JSON-RPC ID types and errors; document the supported shape/version without committing the full schema bundle.
- [ ] Implement a fake child that reads one JSON value per line, writes two notifications plus a correlated initialize response, then remains alive until stdin closes. Flush each response. Add explicit fixture modes for split writes, coalesced frames, malformed JSON, partial-frame EOF, stderr flood, delayed response and ignoring stdin EOF. Use command arguments for mode, never model-supplied shell text.
- [ ] Add the first red transport test: send a request, receive its response while stdin stays open, send a second request, receive another response, then close. Assert both IDs and that the child was not reaped until close. A buffered `os/sh` implementation must not pass.
- [ ] Run the focused command below; expect a missing transport namespace/API failure, not a fixture parse error. Keep the fake child independently smoke-testable with fixed input and exact expected output.

Focused command (repeat after each task, require exit zero and no failed assertions):

```sh
/Users/ndn/development/let-go/lg -source-paths src:test -e '(require (quote attractor.codex-transport-test)) (clojure.test/run-tests) (os/exit (if clojure.test/*test-result* 0 1))'
```

### Task 2: Implement the smallest owned duplex transport

**Files:**
- Create `src/attractor/codex/transport.lg`.
- Extend `test/attractor/codex_transport_test.lg`.
- Create `src/attractor/codex/framing.lg` and
  `test/attractor/codex_framing_test.lg`: isolate byte-bounded incremental frame
  decoding from process lifecycle. This lets protocol correctness proceed while
  exact-process shutdown awaits resolution of the runtime prerequisite below.
  A passing decoder does not satisfy the live transport contract.
  Decoder API: `make-decoder`, `feed!`, `finish!`; feed returns explicit
  `{:raw-json exact-frame-string :message parsed-object}` envelopes so exact
  wire evidence survives EDN serialization. The parsed object currently inherits
  native JSON numeric limitations; RPC must honor the #815 prerequisite below.

Public contract:

```clojure
;; (open! options) -> transport handle
;; options: :command vector, :on-message callback, :on-failure callback
;;          :max-frame-bytes (default 1048576), :shutdown-ms (default 2000)
;; (send! transport message-map) -> nil, or throws typed ex-info
;; (close! transport) -> {:closed? true :reaped? true}
```

- [ ] Write red cases for Unicode split at byte boundaries, several frames in one read, over-limit frame without newline, blank/malformed frames, partial-frame EOF and stderr exceeding 64 KiB. EOF without a partial frame is normal only when closing; otherwise notify the RPC owner.
- [ ] Open stdin/stdout/stderr pipes before `.Start`; use the already-proven `os/exec` interop. Serialize outbound writes through one owner. Read bounded byte chunks and incrementally frame stdout; do not use unbounded `io/line-seq` for production protocol parsing. Decode only complete frames. Drain/discard stderr beyond a 64 KiB diagnostic cap.
  Implementation evidence (2026-09-07): mutable chunk buffers are affected by
  [nooga/let-go#813](https://github.com/nooga/let-go/issues/813). Until fixed,
  use buffered `ReadByte` with bounded frame accumulation, not `.Read` into a
  copied byte-array. See [reproducer and return point](../../let-go-byte-array-interop.md).
- [ ] Use let-go supervision patterns already exercised by `src/attractor/handlers.lg`, `src/attractor/agent.lg`, and their cancellation tests. Keep mutable pending state and callbacks out of competing writers. Bound the inbound queue to 64 frames; overflow fails the connection, settles pending requests and cleans up, never dropping frames silently. Test a paused internal consumer. Internal consumers must be cancellation-aware; do not run arbitrary user callbacks inline. Closing pipes must unblock reader workers before joining them.
- [ ] Add red cases for child launch failure, callback exception, repeated close, a blocked reader, and a child ignoring EOF. Close is idempotent; a deadline escalates to killing only the owned child and `.Wait` reaps it. If kill/reap fails, return a typed shutdown error instead of claiming `:reaped? true`.
  Runtime prerequisite discovered 2026-09-07:
  [nooga/let-go#814](https://github.com/nooga/let-go/issues/814) prevents lookup
  of `exec.Cmd.Process` for exact-child termination. Resolve this or prove an
  equivalent safe owned-process mechanism before claiming bounded shutdown.
  The user-owned runtime checkout has not been changed.
- [ ] Implement cleanup for every partially opened state. Ensure single-`error` Go returns are treated correctly; mechanically test nonzero process exit and failed start rather than assuming nil means success.
- [ ] Run focused tests. Expect every child reaped and no callback after close returns. Commit only transport, fixture and its tests.

### Task 3: Correlate requests and complete initialization

**Files:**
- Create `src/attractor/codex/rpc.lg`.
- Create `test/attractor/codex_rpc_test.lg`.

Public contract:

```clojure
;; (connect! transport-options) -> client in :uninitialized state
;; (initialize! client client-info timeout-ms) -> initialize result
;; (request! client method params timeout-ms) -> result or typed error
;; (notify! client method params) -> nil
;; (close! client) -> transport close result
```

- [ ] Write failing tests for out-of-order response IDs, notifications before a response, server requests, duplicate/unknown response IDs, response errors, deadline expiry, EOF with outstanding requests and repeated initialization. Start request IDs at 1 and allocate monotonically per connection; preserve server request IDs verbatim in responses.
  Include incoming integer ID `9007199254740993`: current native JSON decoding
  rounds it to `9007199254740992` ([nooga/let-go#815](https://github.com/nooga/let-go/issues/815)).
  Exact incoming IDs are a separate runtime/decoder prerequisite; never claim
  full correlation correctness merely because small test IDs work.
- [ ] Implement pending-request correlation; register a waiter before writing its request. On terminal transport failure, settle every pending waiter exactly once. Unknown notifications are ignored unless a subscriber is registered; unknown or duplicate response IDs fail the connection. Unsupported server requests receive JSON-RPC method-not-found, not silence.
- [ ] Implement handshake state `:uninitialized -> :initializing -> :ready`: send initialize using generated-schema fields, await its matching successful response, then send initialized. Become ready only after that write succeeds. Reject regular requests before readiness, and reject repeated initialize. A failed handshake closes and joins the transport. Test explicit rejection and a live child that never replies. The 10-second deadline covers startup plus handshake, not just response waiting.
- [ ] Add an explicit test that initialization emits neither thread/start nor turn/start and requires no account credential payload. Retain only server/version diagnostics; no raw auth/account records.
- [ ] Run the same focused command as Task 1 with `attractor.codex-rpc-test` replacing the required namespace. Expect all cases green. Commit RPC and its tests separately.

### Task 4: Probe the installed server and verify the slice

**Files:**
- Create `dev/codex_handshake.lg`: opt-in, initialize-only client.
- Update `docs/codex-app-server.md` with actual evidence and limitations.

- [ ] Write a probe using `rpc/connect!`, `rpc/initialize!`, and `rpc/close!` in cleanup. Launch the installed `codex app-server --stdio`, use a 10-second handshake deadline and 2-second shutdown grace, and exit nonzero on failure. Print only an EDN summary with Codex version, ready/closed/reaped booleans; do not dump unsolicited raw messages.
- [ ] Run `/Users/ndn/development/let-go/lg -source-paths src:dev dev/codex_handshake.lg`. Expect a checked readiness result and reaped child, without any model turn. Request sandbox escalation if process startup is blocked. A skipped/unavailable live probe must be recorded as unverified, not passed.
- [ ] Run `env PATH="/Users/ndn/development/let-go:$PATH" lgx test`; require zero failures. Run `env PATH="/Users/ndn/development/let-go:$PATH" lgx build` and `bin/attractor --help`; require successful exits. Because the CLI does not yet require the connector, also compile/run a temporary AOT entrypoint that explicitly requires the new namespaces and executes the fake handshake; the normal application build alone is insufficient.
- [ ] Request code review against the design, address verified findings with tests, rerun impacted evidence, and document exact outcomes. No runtime bug claim without a minimized reproducer; report any required let-go changes to the user before editing that checkout.
- [ ] Commit scoped evidence/docs and push the feature branch to the existing public repository. Never stage private notes. State clearly that transport readiness is complete only if these checks pass; Codex turns and multi-agent integration remain outstanding.

## Follow-on boundary

After this slice, implement the backend lifecycle and existing engine event/session
integration as separate reviewed plans. The first multi-agent acceptance remains
Qwen + Codex independent branches -> executable validation -> explicit fan-in,
not a replacement orchestration layer or a shared cross-provider transcript.

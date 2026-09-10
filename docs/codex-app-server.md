# Codex app-server integration

Status (2026-09-08): transport, one-turn agent and registry entry are
implemented and tested against the let-go fake child, and one live turn ran
against the installed `codex-cli 0.153.4`: `bin/attractor agent codex`
with a read-only sandbox returned "codex connected" (37 protocol
records, 3 text deltas, one completed event, exit 0). This backend uses
Attractor's existing orchestration rather than a shared cross-provider
conversation or a second workflow engine.

## Implementation

- `attractor.codex.transport`: `open!`/`send!`/`close!`. The child runs under
  a shell that records its PID and exit status; stdin is a FIFO held open for
  writing, stdout/stderr are files read incrementally through the bounded
  framing decoder. This avoids the byte-array (#813) and boxed pointer (#814)
  interop limits without a Go change. Server requests (approvals, permissions,
  tool calls) are answered with a JSON-RPC error: the agent never grants
  authority on the user's behalf. Close gives the child `:shutdown-ms`, then
  TERM and KILL by exact PID; `close!` is idempotent.
- `attractor.agents.codex/run!`: initialize → initialized → `thread/start`
  (`cwd`, `approvalPolicy`, `sandbox` as the kebab-case `SandboxMode`, optional
  `model`) → `turn/start` with one text input; streams `item/agentMessage/delta`
  as `:text_delta` events and completes on `turn/completed`. `turn/interrupt`
  is sent on cancellation. Options: `--sandbox read-only|workspace-write|
  danger-full-access`, `--approval-policy never|on-request|untrusted`.
- Selected as `bin/attractor agent codex`, `--agent codex` (DOT runs) or
  `/agent codex` (console).

Evidence: `test/runner.lg attractor.codex-transport-test` 4 tests / 41 assertions (duplex
exchange, split/coalesced/delayed frames, malformed/partial-EOF/stderr-flood
failures reported once, ignore-EOF child killed by exact PID);
`test/runner.lg attractor.codex-agent-test` 3 / 15 (completed turn with deltas, failed turn,
refused approval, invalid options, interrupt on cancel). The live server's
rejection of an object-shaped `sandbox` during development is what fixed the
wire format (`SandboxMode` strings, not `SandboxPolicy` objects).

- [Design](superpowers/specs/2026-09-06-codex-app-server-design.md)
- [Transport implementation plan](superpowers/plans/2026-09-06-codex-app-server-transport.md)

## Installed protocol inspection (2026-09-07)

`codex --version` reported `codex-cli 0.153.4`. The following command generated
schemas successfully into a fresh temporary directory:

```sh
codex app-server generate-json-schema --out <temporary-directory>
```

Inspected `v1/InitializeParams.json`, `v1/InitializeResponse.json`,
`RequestId.json`, and the client notification/request definitions:

- Initialize parameters require `clientInfo`, whose `name` and `version` are
  required strings; `title` is optional. Capabilities are optional.
- Initialize results require `codexHome`, `platformFamily`, `platformOs`, and
  `userAgent`. Validate the result but do not publish the home path in evidence.
- Request IDs support strings and signed 64-bit integers. Allocate integer
  client IDs; preserve server IDs without coercion.
- Send `initialized` after a successful initialize response. Readiness is not
  established by process launch alone.
- `codex app-server --stdio` is supported by this installed version.

These are local schema observations, not a live handshake result. No model turn
or authentication request was made. The generated schema bundle is not tracked.
See the [official protocol documentation](https://learn.chatgpt.com/docs/app-server)
for lifecycle context; implementation must verify the installed wire behavior.

## Evidence boundary

The local let-go binary successfully sent and received a line through a live
`/bin/cat` child while stdin remained open. This establishes basic duplex process
I/O through existing interop; it does not establish resource cleanup under
failure, bounded framing, app-server readiness, AOT compatibility, or agent
integration. Those are explicit mechanical gates in the transport plan.

The initial planning checkpoint included no production changes or model trials.
The framing implementation and its evidence are described below; no live
Qwen/Codex model trial has been performed for this connector.

## Runtime findings (2026-09-07)

- [Mutable byte-array interop](let-go-byte-array-interop.md), upstream
  [#813](https://github.com/nooga/let-go/issues/813): Go reads mutate a copied
  slice rather than the caller's array. Buffered single-byte reads were verified
  as a possible bounded-framing workaround.
- [Boxed pointer field lookup](let-go-boxed-pointer-fields.md), upstream
  [#814](https://github.com/nooga/let-go/issues/814): accessing the owned
  `exec.Cmd.Process` field fails before pointer dereference. Exact-child forced
  termination remains unverified; stdin closure alone is not sufficient.

Neither finding changes the orchestration design. The runtime checkout has not
been changed. Use native let-go/Go facilities,
not JVM-shaped replacements; retain the shutdown gate while resolving #814.

## Deterministic fixture evidence

Run from the Codex worktree root:

```sh
/Users/ndn/development/let-go/lg test/probes/codex_fixture_smoke.lg
/Users/ndn/development/let-go/lg -source-paths src:test -e '(require (quote attractor.codex-transport-test)) (clojure.test/run-tests) (os/exit (if clojure.test/*test-result* 0 1))'
```

On 2026-09-07 the smoke harness exited zero: normal, split, coalesced, delayed,
stderr-flood, malformed, partial-EOF and ignore-EOF modes behaved as specified.
The live two-request probe kept stdin open and independently checked fixture
PID liveness before close and disappearance afterward. Every fixture has a
finite safety lifetime; the ignore-EOF check observes that deadline, not a
production transport kill.

The transport contract intentionally exited 1: one test, one missing-namespace
failure, zero errors. The feature branch is therefore not suite-green and must
not merge to main as a completed connector. The fixture is tested scaffolding;
production transport, bounded shutdown and RPC initialization evidence
remain pending. The existing main branch is unchanged.

## Bounded framing implementation

`attractor.codex.framing` incrementally accepts byte chunks and returns explicit
`{:raw-json ... :message ...}` frame envelopes. It bounds payload bytes, validates
UTF-8 before parsing, rejects malformed/non-object JSON and partial EOF, and
latches failures. If any frame in a feed is invalid the entire feed fails;
callers must close the connection rather than retry or assume partial delivery.

Focused direct tests passed 128 assertions (one test), zero failures/errors.
A standalone bundle containing both the decoder and its test ran outside the
repository and passed the same 128 assertions. This tests packaged bytecode,
not native Go AOT lowering or the unimplemented process transport.

The full feature-branch suite completed with 569 tests, 4,839 assertions and one
failure. The missing-transport contract remains deliberately failing; this is
not a green release checkpoint.

```sh
/Users/ndn/development/let-go/lg -source-paths src:test test/probes/codex_framing_check.lg run
/Users/ndn/development/let-go/lg -source-paths src:test -b <temporary-output>/framing-check test/probes/codex_framing_check.lg
# From outside the repository:
<temporary-output>/framing-check run
```

The entrypoint explicitly requires the decoder so bundling includes it; a
runtime-only require from inside the test does not establish that dependency.

Parsed numbers still inherit [JSON precision issue #815](let-go-json-integer-precision.md).
The exact raw JSON survives EDN serialization, but lossless RPC correlation is
not implemented or proven. No pending process-lifecycle requirement is waived
by passing framing tests.

# Codex app-server integration

Status: design and first-slice plan reviewed; fake child and RED transport
contract added. Production connector not implemented yet.
This backend will use Attractor's existing orchestration rather than create a
shared cross-provider conversation or a second workflow engine.

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

No production source changes or live Qwen/Codex model trials accompany these
planning documents.

## Runtime findings (2026-09-07)

- [Mutable byte-array interop](let-go-byte-array-interop.md), upstream
  [#813](https://github.com/nooga/let-go/issues/813): Go reads mutate a copied
  slice rather than the caller's array. Buffered single-byte reads were verified
  as a possible bounded-framing workaround.
- [Boxed pointer field lookup](let-go-boxed-pointer-fields.md), upstream
  [#814](https://github.com/nooga/let-go/issues/814): accessing the owned
  `exec.Cmd.Process` field fails before pointer dereference. Exact-child forced
  termination remains unverified; stdin closure alone is not sufficient.

Neither finding changes the orchestration design. Neither runtime checkout nor
production connector code has been changed. Use native let-go/Go facilities,
not JVM-shaped replacements; retain the shutdown gate while resolving #814.

## Deterministic fixture evidence

Run from the Codex worktree root:

```sh
/Users/ndn/development/let-go/lg dev/codex_fixture_smoke.lg
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
production transport, bounded shutdown, RPC initialization and AOT evidence
remain pending. The existing main branch is unchanged.

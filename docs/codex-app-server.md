# Codex app-server integration

Status: design and first-slice plan reviewed; connector not implemented yet.
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

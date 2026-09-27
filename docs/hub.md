# Hub usage

The hub owns native sessions, workflow runs, external-agent jobs, events,
human questions and cancellation. CLI commands use the same request contract;
tools execute in their owning sessions.

## Run a shared host

```sh
bin/attractor hub --mock --port 4555
```

From other terminals:

```sh
bin/attractor console --connect 4555
bin/attractor console --connect 4555 --tui
bin/attractor serve --connect 4555 --port 127.0.0.1:7070
```

The host accepts model/backend options; `--mock` needs no live model. Attaching
clients use the host's configuration. `/quit` detaches the console and preserves
hub-owned work. `/answer <key or text>` answers a pending human gate, preferring
the focused workflow. `--auto-approve` is optional.

Stop the host explicitly:

```sh
bin/attractor hub --stop 4555
```

Stop acknowledges the request before the host closes connections and shuts down
its work. `hub --port 0 --port-file PATH` chooses an available port and publishes
it in a new file; normal shutdown removes the host's own file.

## Ownership by command

| Command | Hub ownership |
|---|---|
| `run`, `resume`, `agent` | Embeds and owns a hub for the command. |
| `console` | Embeds a hub unless `--connect PORT` is supplied. |
| `hub` | Owns a persistent hub and loopback nREPL listener. |
| `serve` | Owns a hub and nREPL listener, with HTTP routed through nREPL. Use `--nrepl-port PORT` to select that listener's port. |
| `serve --connect PORT` | Attaches HTTP to an existing hub; stopping the HTTP process leaves the host's work alive. |

`--connect` names a loopback nREPL port, not a URL. HTTP's `--port` is a listen
address. The nREPL protocol uses bencode envelopes containing EDN data; it also
provides explicit evaluation in the persistent console namespace. Treat it as
trusted local access, not an authenticated multi-user service.

## Current limits

- Connections do not reconnect automatically. Lost mutation replies have an
  unknown outcome and must not be retried blindly.
- Session result lookup retains only the latest turn. Event cursors support
  replay within retained history, not durable recovery across host restarts.
- Request waits are bounded, but client lock acquisition and socket writes do
  not have independent deadlines; payload checks follow frame decoding.
- Signal-triggered graceful shutdown and an owned HTTP shutdown API remain
  unestablished. Explicit host stop is the supported lifecycle path.
- This is an Attractor nREPL extension, not full editor nREPL middleware support.

Implementation: `src/attractor/cli.lg`, `nrepl_client.lg`, `nrepl_server.lg`,
`nrepl_hub.lg`, and `hub_http.lg`. Contract tests cover console attachment,
question answering and shared HTTP controls. Native/compiled probes live in
`test/probes/nrepl_hub_check.lg` and `test/probes/hub_host_check.lg`.

The [archived nREPL notes](_archive/nrepl-hub.md) retain protocol details and
dated verification; their old separate-HTTP-registry and patched-runtime
statements are superseded by the current implementation and stock let-go 1.13.0.

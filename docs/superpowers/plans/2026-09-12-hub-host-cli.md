# Hub host CLI

Provide `hub --port PORT` to run the existing configured workflow hub behind the
native nREPL adapter, and `hub --stop PORT` to stop that CLI host. Port zero is
allowed for startup. An optional `--port-file PATH` writes the assigned decimal
port for native process tests and local tooling; remove it on normal shutdown.

The adapter exposes `attractor/stop` only when started with `:allow_stop true`.
It writes the done response before signaling its host. Embedded adapters default
to no host-stop operation. The CLI waits for this signal, then closes/joins the
adapter and stops the hub. Startup/bind/publication failures clean up resources.
Do not claim signal-triggered graceful shutdown: the runtime signal API is not
portable to this macOS runtime.

Test protocol exposure and acknowledgement over real sockets, then launch the
compiled CLI host on port zero, attach a compiled console, stop via the compiled
CLI, and verify process completion and port-file cleanup. No model calls.

Implemented and verified. Before implementation the host probe observed the
compiled CLI's unknown-command failure; the adapter probe observed rejected stop.
Both now pass, including stopping a workflow waiting at a human gate and rejecting
stop on default embedded adapters. Host unit tests pass 3/10/0; existing CLI and
connection tests pass 8/66/0. The full-suite result is recorded separately after
completion. No signal-handler support or HTTP ownership migration is claimed.

Full suite completed with exit zero: 1019 tests, 9362 assertions, zero failures
(`/tmp/attractor-hub-host-suite.log`). The compiled lifecycle probes are separate
wire evidence; a green suite alone does not close the original-spec audit.

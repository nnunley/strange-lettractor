# Attached console CLI

Add `console --connect PORT` for the loopback nREPL adapter. Validate the port
before startup. Reuse the line/TUI frontends with remote console options; avoid
creating or stopping a local hub on this path. Always detach the console and
close its connection when the frontend exits. Existing local mode stays intact.

Verify selection/lifetime with a CLI integration test, then build the executable
and drive the real command against a native hub using an owned shell process and
scripted stdin. Confirm exit leaves that hub responsive. Document that an
embedding host currently starts the hub listener; a dedicated service command is
not part of this change.

Implemented and verified: eight assertions failed before implementation. CLI
connection tests now pass 2/9/0; existing CLI tests pass 6/57/0. `make build`
succeeds. The native wire probe launches the rebuilt executable with `/new` and
`/quit` on stdin, verifies exit zero and finds the new open session in the same
remote hub afterward. `--tui` shares this connection setup but has not received
a new interactive terminal smoke test.

# Native nREPL hub adapter implementation plan

Goal: attach native let-go clients to an existing hub over bencode, without
moving workflow or session ownership into a connection.

Architecture: `attractor.nrepl-hub` accepts `describe` and `attractor/request`.
The latter carries one EDN map in `payload`; its `:op` selects an explicitly
allowed hub operation. The outer nREPL string `id` controls reply correlation.
Replies carry EDN in `value` plus nREPL `status` strings. Submission replies omit
process-local completion promises; clients inspect the corresponding result
operation. Event retrieval takes a hub client ID and cursor. Evaluation and hub
shutdown are not exposed until their transport lifecycle is implemented.

The listener and accepted connections belong to the adapter. Closing it closes
all sockets and joins its workers, but never stops its supplied hub. Disconnect
does not cancel work. Standard eval/session middleware, pushed subscriptions,
console attachment and HTTP migration remain later steps; this adapter must not
advertise those as implemented.

- [x] Write handler tests for describe, correlation, exact EDN parsing, allowed
  operations, and session submit/result data; run before implementation.
- [x] Implement data dispatch in `src/attractor/nrepl_hub.lg` and pass tests.
- [x] Add owned listener lifecycle and a native loopback probe with two clients,
  disconnect/reconnect, shared hub state and shutdown cleanup.
- [x] Verify the native probe and impacted hub tests; record actual limits.

Evidence and precise remaining scope are in `docs/nrepl-hub.md`. Network lifetime
code lives separately in `src/attractor/nrepl_server.lg`. Both new probes initially
failed to load their missing implementation namespace; subsequent handler tests,
native wire checks and standalone-bundle checks pass. No complete standard nREPL
middleware or HTTP/console migration is claimed.

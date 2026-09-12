# Console transport integration

Goal: attach the existing console dispatcher to an nREPL hub without passing a
hub state object or owning its lifetime.

Add a native nREPL client with correlated synchronous request/reply handling,
serialized access to its decoder, explicit close and no mutation retries. Add
`:request_fn` and `:events_fn` injection to console options, preserving local
defaults. Cursor-expired errors must include the oldest retained cursor so the
console can recover without reading the hub's internal log atom.

Verify an injected transport with no local hub, then run the actual console
dispatcher through nREPL, including text submission, output and detach. Keep CLI
attachment separate until configuration and remote evaluation are wired; do not
advertise unsupported console functions as complete.

Implemented: injected console request/event functions, cursor-expiry recovery
metadata, and `attractor.nrepl-client` with correlation and explicit socket close.
The initial external-console test failed by trying to use a nil local hub;
it now passes. Console tests: 9/78/0; nREPL handler tests: 3/18/0; hub session
tests: 17/138/0. The native and bundled wire probes pass the remote console path.
CLI attachment and remote evaluation remain future work, as documented above.

# Shared HTTP control adapter

Build `attractor.hub-http/make-handler` over a synchronous hub request function.
Implement existing list/status/context/questions/answer/cancel semantics with no
private pipeline registry. Keep per-run event history in the hub so status counts
and subsequent SSE replay use the same execution owner. Expose history by a
validated cursor through `:workflow/events`.

Test a run submitted through nREPL dispatch, inspected and answered through the
HTTP handler, then observed completed through the hub. Also verify cancellation
and wrong-run question rejection. Until submission admission, graph/checkpoint
routes and SSE are implemented and verified, this adapter is not selected by the
CLI's existing HTTP server. Do not claim full HTTP migration from control tests.

Implemented: control adapter and hub-owned per-run history. Shared HTTP tests
pass 2/22/0; workflow inspection tests pass 2/21/0. Tests invoke the HTTP/nREPL
handlers directly against actual hub-owned workflows; no HTTP socket or CLI
selection claim is made. Remaining routes return 501 in this new adapter.

SSE/checkpoint follow-up: three assertions failed before these routes existed.
The shared adapter suite now passes 3/33/0, including an active stream waiting
for a human answer, terminal delivery and cursor replay. Checkpoints are read in
the hub. The prior timed hub failures passed on an unchanged recheck (13/85/0);
earlier failures remain recorded in `docs/shared-http-adapter.md`.

# Remote console evaluation

Extend the existing hub evaluation lifecycle with ID-based result lookup. Keep
completion promises and actual evaluated values in the hub. The nREPL adapter
exposes `:eval/submit` and `:eval/result`; successful evaluation results and replay
events replace raw `:value` with its `:value_repr` string while preserving stdout.
The console renders that representation directly. This preserves persistent hub
namespace evaluation without attempting to deserialize arbitrary runtime objects.

Write tests for a function-valued evaluation with stdout, namespace persistence,
and a native attached console evaluation. Run before implementation, add lookup
and representation conversion, then rerun evaluation/session/console coverage.
Standard nREPL eval middleware and evaluation cancellation are separate unfinished
contracts; the adapter must continue to advertise only its actual protocol ops.

Implemented and verified: seven new assertions failed before implementation.
The nREPL handler suite now passes 4 tests/28 assertions; existing hub console
operations pass 13/85 and console dispatcher tests pass 9/78. The native socket
probe passes remote `: form` evaluation with stdout and result rendering. The hub
retains its original value, while the adapter changes only its wire representation.

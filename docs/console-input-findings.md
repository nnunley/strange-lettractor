# Console input findings

Inspected 2026-09-06 after fan-in checkpoint `1fe6bd6`.

## Observed failures

Calling the real console interviewer with a freeform question and
`:timeout_seconds 0.05` immediately throws `io/flush expects 1 arg`.
`src/attractor/interviewer.lg` calls `(io/flush)` in all three input paths;
the local runtime's `pkg/rt/ions.go` requires a writer argument. This is an
application API misuse, not evidence of a let-go Clojure-compatibility bug.

With only that flush call temporarily replaced by a no-op through `with-redefs`
in a diagnostic process, the same question remained blocked after the tool's
one-second observation window, exceeding its 50ms timeout. Supplying
`probe complete` then returned that text normally and the process exited 0.
No process or blocked input reader from this probe remains running.

The human handler constructs questions without `timeout_seconds`, so fixing
console input alone would not connect DOT execution to question deadlines.
The upstream snapshot §§6.4–6.5 requires nonblocking console input, returning
the question default on expiry or `:timeout` when no default exists.

## Native input boundary

Local `pkg/rt/iort.go` implements `read-line` using buffered
`ReadString('\n')`; it does not consult its execution context for cancellation
while the read is blocked. A timed future around that call would not establish
reader cleanup or prevent a late read from consuming a later question's answer.

`term/key-pending?` plus `term/read-key` is not a complete general replacement:
the native readiness check returns false for empty/EOF input, operates on the
terminal key source rather than the bound `*in*` reader, and tokenization may
need additional bytes. A terminal-only implementation would leave redirected
input and reader bindings unproved.

## Proposed direction (not yet approved or implemented)

Prefer a cancellation-aware timed line-input primitive in let-go, with an
explicit distinction between a line, EOF, timeout and I/O failure; preserve
partial data across deadlines and do not close borrowed stdin. Define ownership
and unsupported-reader behavior explicitly. Expose proper `vm.Nil, err` error
returns and prove native supervision cleanup with real pipes/terminal input.

Then keep Attractor's answer parsing and deadline/default policy in let-go:
inject a bounded input operation and clock for deterministic tests; fix prompt
flushing; connect human-node question deadlines/cancellation; cover all
interviewer implementations and public routing. Do not use detached reader
workers or a platform-specific shell command as the portability contract.

An alternative is a project-owned native host extension, but that duplicates
runtime I/O machinery and changes the current lgx/AOT integration. A detached
future is simpler but does not satisfy the joined-cleanup requirement.

The local let-go checkout is user-owned and dirty. No upstream files were
modified; the native API contract and authority to implement it there still
need confirmation. This does not block independent remaining Attractor work.

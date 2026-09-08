# Native HTTP scope cancellation gap

## Local runtime fix, 2026-09-08

A fix is implemented in the isolated local let-go workspace
`.worktrees/let-go-http-cancellation`, jj workspace `http-scope-cancellation`,
based on `bdd8268c`, checkpoint `f8c3eb13b433980968a9af94d7938c3b361bfb9f`
(`fix/http-scope-cancellation`). This is not yet an upstream release, and the existing
`~/development/let-go/lg` executable has not been replaced.

`http/get`, `http/post`, and `http/request` now use the runtime's existing
context-aware native entrypoint and attach `ec.Context()` to the Go HTTP
request. The context remains attached to streamed bodies after the native call
returns; there is no premature deferred cancellation at that boundary.

Runtime tests in `pkg/rt/http_cancellation_test.go` cover all three methods
while held before headers, during buffered body reads, and during streamed
body reads. All nine cases failed on the base with one live worker each.
They pass with the fix, including server-observed disconnect, a cancellation
error, and zero live workers. Normal buffered/streamed responses and sibling
scope isolation are also covered. Ten repeated focused runs and five race
runs passed. `pkg/api/http_cancellation_test.go` additionally exercises a
compiled let-go function and verifies that cancellation reaches Lisp `catch`;
ten race runs passed. Runtime/API vet, full `pkg/rt`, `pkg/vm`, and `pkg/api`
tests, and the focused bootstrap-mode tests passed.
An actual Claude read-only review through the Attractor connector found no
actionable defects. Abandoned streams with no read/close are not directly covered
by these tests. Attractor's full suite against the freshly built runtime and cwd
fix passed: 728 tests, 7,035 assertions, zero failures, exit 0.

Build the isolated runtime with `go build -o build/lg .` and point `LGX_LG`
at that executable for Attractor. These tests do not establish native support
for Attractor's signal/timeout map options, nor complete Attractor's separate
abort/join semantics. Dynamic context-capacity discovery still needs wiring;
this fix supplies its cancellable native HTTP prerequisite.

## Original reproduction

Verified 2026-09-07 using local `lg dev (bdd8268)`, source HEAD
`bdd8268c9cb3acf369f0854bada47af79d1d673d`. No runtime source was edited.
Tracked upstream as [nooga/let-go #816](https://github.com/nooga/let-go/issues/816).

`http/request` creates `http.NewRequest` and executes `http.DefaultClient.Do`
in `pkg/rt/http.go` without the current VM scope context. Thus closing the
owning scope cannot interrupt a request blocked waiting for response headers.
The same implementation does not read Attractor's forwarded `:abort_signal`
or `:timeout` options; forwarding them is not proof of native support.

## Real socket reproduction

Run `go run dev/http_cancellation_server.go` from this worktree. It prints a
loopback URL. In another shell run one of the following, replacing URL with that
address. Use a fresh fixture server for each check.

```sh
/Users/ndn/development/let-go/lg dev/http_scope_cancellation_check.lg URL
/Users/ndn/development/let-go/lg -source-paths src dev/http_llm_cancellation_check.lg URL
```

The server confirms receipt of a held request before the caller cancels. It
counts held request handlers and request-context cancellations independently of
the let-go process. The direct check closes a native scope with a 100ms drain
budget. Observed: drain warning, `:live 1`, server `active=1`, `canceled=0`.
The Attractor check calls public `llm/generate` through the native OpenAI adapter
against the same held HTTP endpoint. Observed: `:category :abort` returned while
`:live 1`, server `active=1`, `canceled=0`. Both checks intentionally exit 1.

Both final probes observe cancellation for up to 500ms, require worker settlement
and zero live workers for a pass, and perform release/shutdown in cleanup. Final
observations remain `active=1`, `canceled=0`, `live=1`; after explicit release,
both print `:cleanup-settled true`, `:cleanup-live 0`. The fixture consumes up to
1 MiB of the request body before reporting readiness, so Go's HTTP server can
watch for disconnects. The earlier POST probe without this drain was inadequate
server-cancellation evidence and is superseded by this corrected run.

The fixture also releases requests after 10s
and closes its server after 30s as safety bounds. Initial sandbox/approval
attempts hit denied connections or expired fixtures; those are not cancellation
evidence. Both actual reproductions used permitted loopback access and confirmed
the fixture process exited 0.

## Restoration boundaries

The runtime needs context-aware native HTTP invocation, including cancellation
before headers and during response-body reads. Scope cancellation should close
the connection and settle the owned worker. Tests should verify server-side
request-context cancellation, not only a caller-side timeout. Native HTTP
options for connect/request/read deadlines also need a defined supported API;
Attractor-specific signal map conventions need not become the runtime API.

Attractor separately needs ownership/join semantics around `controlled-invoke`
and its stream monitor. It currently throws on abort without joining the task.
Blindly adding an indefinite join before fixing the transport would turn prompt
cancellation into a wait on an uncancellable HTTP request. Retain both probes
and extend them to stalled bodies/streaming once native cancellation is wired.

This is evidence for ULLM-CANCEL-01, not completed cancellation conformance.
No model endpoint, credentials, or JVM APIs are involved. The fixture is Go
test infrastructure; production remains let-go.

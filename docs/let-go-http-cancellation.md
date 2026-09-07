# Native HTTP scope cancellation gap

Verified 2026-09-07 using local `lg dev (bdd8268)`, source HEAD
`bdd8268c9cb3acf369f0854bada47af79d1d673d`. No runtime source was edited.

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

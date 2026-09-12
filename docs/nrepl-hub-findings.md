# nREPL hub capability investigation

Later 2026-09-12: local `net/listen`, `net/local-address`, `net/accept` and listener
close are now implemented and pass native/bundled wire checks. The tracked patch
is `runtime-patches/net-listener.patch`. This resolves the local primitive gap;
it does not change stock nREPL dispatch or establish the product's nREPL adapter.

2026-09-12 recheck: the configured runtime still exposes only `close!`, `dial`,
`read!`, and `write!` in `net`; its nREPL dispatch remains fixed and interrupt
remains a response-only stub. The user reaffirmed nREPL for let-go clients and
HTTP for other clients, sharing one owner. See
[shared-hub-transport-plan.md](shared-hub-transport-plan.md) for current code
evidence and the migration sequence.

The console must be an RPC client, not the framework owner. The stock local
let-go nREPL is not yet a sufficient framework hub transport.

Inspected local `pkg/nrepl/server.go` and `pkg/rt/bencode.go`; live runtime banner
reported dev bdd8268. These findings describe this checkout, not every nREPL
implementation or a completed Attractor integration.

- Server binds loopback and supports OS-assigned port discovery.
- Operation dispatch is a fixed Go switch; no custom handler registration was
  found in that server. An `attractor/sessions` request returned unknown-op.
- Eval buffers output and emits it only after CompileMultiple returns. A bounded
  eval printing before a 500ms wait produced no response within a 50ms read.
- Interrupt handler only responds done/session-idle; it does not signal the eval.
  A separate connection requesting interrupt during that bounded eval received
  session-idle. Do not use this as framework cancellation.
- Eval uses the shared compiler context rather than looking up the supplied
  session. A request naming a nonexistent session successfully evaluated (+ 40 2).
  Session isolation and unknown/closed-session rejection need separate contracts.

Live probe: `/tmp/lettractor-nrepl-probe.AIcFXP/probe.lg`, native let-go only,
1 test / 5 assertions / zero failures, exit 0. These assertions confirm observed
limitations, not desired acceptance. A subsequent run strengthened the timeout
assertion to require a timeout diagnostic, and took the actual ephemeral port as
an argument: 1/5/0, exit 0. Source inspection remains stronger evidence for the
buffering/interrupt implementation than this time-bounded wire observation; the
probe is not a comprehensive upstream session-isolation regression suite. The
owned loopback server was stopped after both runs. No runtime source edited.

## Next decision

Evaluate a let-go-owned extensible nREPL hub using existing net/bencode facilities
versus a framework RPC channel alongside stock nREPL for explicit trusted eval.
Do not encode all commands as arbitrary eval just to reuse the existing server.
Preserve `.edn` application data; nREPL bencode framing does not by itself change
the application's serialization policy. Authentication/local permissions,
subscription backpressure, request IDs, cancellation and reconnect/replay must
be explicit before choosing the hub contract. Upstream issues should use isolated
reproducers and be checked for duplicates.

Existing upstream breadcrumbs (verified open):

- [#586: embeddable nREPL and shared sessions](https://github.com/nooga/let-go/issues/586).
- [#589: evaluation interruption / nREPL interrupt stub](https://github.com/nooga/let-go/issues/589).
- [#592: per-evaluation output and namespace routing](https://github.com/nooga/let-go/issues/592).

No duplicate issues filed. These proposals primarily discuss Go embedding;
our product remains let-go and needs a language-level extension surface.

The stock `net` namespace also lacks listen/accept; details and the reviewed
upstream request are in `hub-listener-runtime-request.md`. Neither the existing
HTTP server nor stock nREPL is a proved streaming hub substitute.

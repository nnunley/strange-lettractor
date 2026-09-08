# Runtime request: owned TCP listeners for a let-go RPC hub

Status: independently reviewed; acceptance details posted on existing
[let-go #523](https://github.com/nooga/let-go/issues/523#issuecomment-5579712836).
No runtime files modified and no listener implementation claimed.

Strange Lettractor needs a long-lived hub that owns agents/workflows while
terminal clients attach and detach independently. Product code, including
protocol dispatch and supervision, must remain let-go.

This preserves the library-first/event-driven boundaries in the snapshot
`coding-agent-loop-spec.md` sections 1.2–1.3 and the streaming-first SDK principle
in `unified-llm-spec.md` section 1.2. A new hub protocol does not replace the
existing HTTP/SSE conformance obligations in `attractor-spec.md` section 9.5.

## Verified gap

Local `lg` dev bdd8268 reports `(close! dial read! write!)` for
`(sort (keys (ns-publics 'net)))`. The native `net` wrapper has no listener.
Existing bencode read/write accepts the private native connection wrapper, so
exposing an arbitrary reflected Go net.Conn alone would not establish bencode
compatibility. Stock nREPL dispatch is not extensible; see the companion findings.

Upstream #523 already proposes server-side sockets; #525/#526 delivered the
TCP client and bencode only. This request makes that follow-up concrete, rather
than proposing another networking namespace or a Go product server.

## Proposed minimal language contract (names subject to upstream review)

- `(net/listen host port)` returns an owned TCP listener. Explicit host required;
  our hub passes `127.0.0.1`. Port zero binds once and permits OS allocation.
- `(net/local-address listener)` returns host and actual bound port as data.
  Do not reserve a port separately and introduce a free-port/bind race.
- `(net/accept listener)` returns the same connection representation as dial,
  usable with existing net and bencode operations.
- `(net/close! listener)` is idempotent and wakes a blocked accept. Closing a
  listener does not implicitly close already accepted connections: the hub's
  supervisor owns those separately. Existing connection close remains available.
- Accept/listen failures surface as catchable let-go errors using the runtime's
  normal value/error contract. No process exits or panic-only API.
- Preserve native/WASM gating; unsupported targets fail explicitly.

## Mechanical acceptance

Native let-go test starts loopback port zero, discovers the actual port, accepts
two clients, and exchanges multiple coalesced/fragmented bencode frames through
the existing decoder. Assert the existing normalized value contract (keywords
become strings, lists become vectors, dictionary keys become strings), not exact
let-go value identity. Round-trip supported frame values without encoding nil,
booleans or floats into bencode silently. Application values can be explicit EDN
payload strings; protocol choice must not weaken the reader contract.

Use bounded synchronization to prove closing the listener wakes accept, repeated
close is harmless, an accepted connection survives listener close, and closing
that connection wakes its blocked read. Join owned tasks; no sleep-only ordering,
free-port probing, detached timeout future, fixed test ports or leaked listeners.
Test bind failures and failed accept as catchable values/errors. Run the same
fixture from a standalone bundle, without claiming native-Go AOT parity.

## Scope and alternatives

This is a primitive gap, not a reason to rewrite the framework in Go. The
documented lginterop/gogen tooling exists and can generate Go wrappers, but those
must be registered in a custom runtime build; they are not dynamically loadable
imports in the current stock lg. A native net.Conn wrapper also differs from the
existing net/bencode handle representation. We have not proved that generated
wrapper route end-to-end, so do not call it impossible or silently substitute it.

HTTP request/response is available today, but the current http/serve path buffers
responses and hides server shutdown. Polling it would not prove the intended
streaming hub. Extending the listener primitive lets the hub protocol, request
registry, event subscriptions and supervision live in `.lg`. Do not duplicate
existing upstream interruption/session issues #586/#589/#592 in this request.

Next product work can proceed on the hub's actual agent/workflow ownership API
with in-process public integration tests. Wire-level streaming, disconnect and
reconnect remain explicitly unproved until a usable transport exists.

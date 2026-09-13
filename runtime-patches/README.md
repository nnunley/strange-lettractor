# Local runtime patches

For the complete pinned build recipe, follow [the project README](../README.md#build-and-run).
Both patches apply to fork revision `46244c4fa8169b8138aa1c29f31c8a6102ed1755`;
a fresh clone with them passes the Attractor suite and native transport probes.
See [runtime build evidence](../docs/runtime-build-audit.md) for commands,
patch hashes, and the distinction from an upstream release.

## Owned TCP listeners

`net-listener.patch` adds native `net/listen`, `net/local-address`, and
`net/accept`, and extends `net/close!` to listeners. Explicit host and port are
required; port zero binds once with OS allocation. Accepted connections use the
existing net/bencode handle. Closing a listener wakes accept without closing its
accepted connections. The owner must close those connections separately. These
are explicitly owned handles, not automatically scope-cancelled resources.

Apply this patch with `git apply` from a compatible let-go source tree, build the
runtime, then run `test/probes/net_listener_check.lg run` with that binary. The
same probe can be bundled with `lg -b /tmp/listener-check ...` and run standalone.
It uses real loopback sockets and checks two clients, port allocation, bind
failure, message framing, bidirectional replies, close wakeups and validation.
The existing Go `Test(Net|Bencode)` tests also pass on the local implementation.

This patch is applied in the configured local runtime and preserved here because
the runtime source snapshot is ignored. No upstream listener release or complete
nREPL integration is claimed. Browser namespace stubs include the new names and
continue to reject TCP operations explicitly.

Verification on 2026-09-12: the WASM runtime cross-build succeeds; after promoting
the native runtime, `make test` passes 1009 tests and 9313 assertions with zero
failures (`/tmp/attractor-listener-suite.log`). The full suite includes the recent
HTTP and hub-result changes. This does not verify a finished nREPL adapter.

## JSON string keys

`json-string-keys.patch` fixes let-go's JSON object conversion: VM string keys
must use their contents, not their reader representation. Previously `"q-id"`
became a JSON key containing literal quotes, breaking HTTP question answers and
context lookups. Keyword keys retain their unprefixed names.

The patch includes a Go regression covering ordinary, empty, escaped and Unicode
keys. It is applied in `.worktrees/let-go-http-cancellation`, an ignored runtime
source snapshot; this tracked patch preserves the change. It has not been
confirmed in an upstream release.

To apply to a compatible let-go source tree, from that tree run:

```sh
git apply --check /path/to/attractor/runtime-patches/json-string-keys.patch
git apply /path/to/attractor/runtime-patches/json-string-keys.patch
go test ./pkg/rt -run TestJSONObjectKeysPreserveStringContents -count=1
go build -o build/lg .
```

Use a Go executable matching `GOROOT`. Then rebuild Attractor with `make build
LGX_LG=/path/to/let-go/build/lg` and run the native wire probe described in
`docs/http-question-audit.md`. This patch alone does not provide the other local
runtime reader and cancellation changes documented in `docs/let-go-followups.md`.

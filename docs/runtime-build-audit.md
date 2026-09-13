# Pinned runtime build audit

The former README cloned a moving fork branch and built it without applying
Attractor's additional runtime patches. A fresh clone at
[`46244c4fa8169b8138aa1c29f31c8a6102ed1755`](https://github.com/nnunley/let-go/commit/46244c4fa8169b8138aa1c29f31c8a6102ed1755)
reproduced both missing capabilities: `net/listen` was unavailable and writing
then reading `{"key" "value"}` through JSON did not preserve the map.

The README now pins that revision and applies both tracked patches before
building. Both patches pass `git apply --check` on the fresh checkout:

| Patch | SHA-256 |
| --- | --- |
| `runtime-patches/net-listener.patch` | `5cc6f3dc98a079026f4afe301a92959b1ba1cd00a9adfd41071cc3129a62abc1` |
| `runtime-patches/json-string-keys.patch` | `8e050ce6ad550cb4c4d58d5c94618fb1c9af32caee85e405b4b236ec626978f2` |

The checkout was built using Go 1.26.5 on darwin/arm64. Runtime tests pass with
`go test ./pkg/rt -run 'Test(Net|Bencode|JSONObjectKeysPreserveStringContents)' -count=1`.
The native `test/probes/net_listener_check.lg run` probe also passes its eleven
checks: ephemeral port binding, bind failure, two clients, coalesced and
fragmented frames, bidirectional bencode, listener and read wakeups, idempotent
close, accepted-connection lifetime, and invalid arguments.

Attractor verification against the new executable:

- `make test LGX_LG=<fresh-checkout>/build/lg`: 1145 tests, 10284 assertions,
  zero failures, exit 0. Log: `/tmp/attractor-pinned-runtime-suite.log`.
- `make build LGX_LG=<fresh-checkout>/build/lg`: exit 0.
  Log: `/tmp/attractor-pinned-runtime-build.log`.
- `test/probes/nrepl_hub_check.lg run`, using the fresh runtime and newly built
  Attractor executable: all ten checks pass, covering shared sessions, two
  clients, disconnect survival, reconnect results, event replay, remote console
  and evaluation, compiled-console attachment, HTTP-peer closure, and cleanup.

The verification checkout was `/tmp/attractor-runtime-check.rAT0iN/let-go`;
the README uses `.worktrees/let-go-pinned` so normal builds can reuse their
runtime. The existing local runtime and environment configuration were not
replaced. These results establish the documented supported build independently
of the older ignored source snapshot.

This establishes a reproducible fork-plus-patches recipe, distinct from upstream
release availability. As checked on 2026-09-12, the latest published upstream
release is [v1.12.2](https://github.com/nooga/let-go/releases/tag/v1.12.2) from July 20.
PRs [#848](https://github.com/nooga/let-go/pull/848),
[#849](https://github.com/nooga/let-go/pull/849),
[#850](https://github.com/nooga/let-go/pull/850),
[#851](https://github.com/nooga/let-go/pull/851),
[#852](https://github.com/nooga/let-go/pull/852),
[#853](https://github.com/nooga/let-go/pull/853),
[#854](https://github.com/nooga/let-go/pull/854), and
[#855](https://github.com/nooga/let-go/pull/855) have merged since that release;
HTTP-timeout PR [#856](https://github.com/nooga/let-go/pull/856) remains open.
No stock-release compatibility claim follows from those merge statuses.

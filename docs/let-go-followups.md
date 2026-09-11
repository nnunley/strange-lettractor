# Upstream let-go follow-ups

These are temporary workarounds or unproved runtime guarantees, not permanent
design choices. Revisit this checklist whenever updating the local let-go checkout
or binary. An issue being closed is not sufficient: verify the fix is present in
the actual configured compiler and rerun the relevant behavior checks.

| Issue | Current application seam | Revisit when fixed |
|---|---|---|
| [#801: metadata and map discards](https://github.com/nooga/let-go/issues/801) | Local runtime `425d8461` data-reading mode for `clojure.edn/read-string` and `edn/read-all-string`; `src/attractor/composition.lg` reads mappings natively (scanner and `compat/` suite removed 2026-09-08) | When upstream ships an equivalent data reader, verify `composition_contract_test.lg` and the artifact set round-trip on the release and drop the local patch. |
| [#805: future exceptions](https://github.com/nooga/let-go/issues/805) | `src/attractor/handlers.lg` parallel worker error records and coordinator collection | Reassess explicit exception transport; preserve cleanup-before-propagation and ordered results. |
| [#806: async helper scope ownership](https://github.com/nooga/let-go/issues/806) | Parallel invocation scope; `test/attractor/parallel_join_contract_test.lg` | Add real async-helper descendant cancellation/join evidence and remove the documented ownership exception only when proved. |
| [#807: unfinished trailing forms](https://github.com/nooga/let-go/issues/807) | Test discovery checks and independent JVM reader checks | Verify malformed sources fail visibly across evaluation, namespace loading, and AOT; then reassess the extra manual syntax cross-check. |
| [#808: unary negation overflow](https://github.com/nooga/let-go/issues/808) | `src/attractor/fan_in.lg` descending score comparison | Verify ordinary `(- Long/MIN_VALUE)` and first-class/apply calls throw overflow. Retain direct comparison: Clojure also cannot safely negate this score. |
| [#809: UUID string coercion](https://github.com/nooga/let-go/issues/809) | `src/attractor/ids.lg` is the only place `random-uuid` is stringified; every run directory, session/turn/job id and wire id goes through `ids/uuid-text` or `ids/prefixed` (a `pipe-#uuid "..."` run directory was observed before this, 2026-09-08) | Verify `str` returns canonical UUID text while `pr-str` and direct UUID printing remain tagged; keep `attractor.ids` as the single seam either way. |
| [#810: asymmetric nested sequence equality](https://github.com/nooga/let-go/issues/810) | Complete human-question comparisons in `test/attractor/interviewer_contract_test.lg` | Verify vector/lazy-sequence values compare equally inside maps in both operand orders, then restore whole-question equality instead of comparing options separately. |

Known accepted divergence: let-go counts Unicode runes rather than JVM UTF-16
chars. The user confirmed this is intentional; [#812](https://github.com/nooga/let-go/issues/812)
was filed unnecessarily and is not a restoration requirement or blocker. Write
confirmations retain explicit `.getBytes "UTF-8"` because neither rune counts
nor UTF-16 char counts measure UTF-8 bytes.

## Restoration checks

1. Record local let-go source revision and rebuild its binary through the let-go
   project's normal workflow. Keep `LGX_LG` pointing at that actual local binary.
2. For #801, run `/Users/ndn/development/let-go/lg -source-paths src:. compat/run_mapping.lg`.
   The current five failures must become passing acceptance assertions. An upstream
   fix alone cannot make this pass: replace the application scanner as well.
   Continue to enforce exactly one resulting string/string map, destination rules,
   and no evaluation. Move restored acceptance into default discovery and replace
   temporary rejection assertions. Keep `.edn` filenames and broader reader checks.
3. For #805, verify both ordinary and timed deref throw the original worker failure,
   preserve exception data across repeated derefs, and distinguish successful nil
   from pending timeouts. Simplify only the redundant workaround, not the completion
   records or primary-error/cleanup ordering the scheduler still needs. Rerun
   worker-, clone-, and launch-failure regressions and external cancellation races.
4. For #806, use bounded channel operations and unconditional fixture cleanup to
   test `async/map` created inside the invocation. Close must cancel/join the worker,
   close its output, prevent late callbacks, and preserve sibling work. The old
   diagnostic reproducer's post-close blocking send must NOT be reused unchanged
   after the fix. Audit other helpers independently. Retain native scope ownership
   and indefinite drain; those are design requirements, not workarounds.
5. For #807, run deliberately unfinished trailing list/vector/map/string inputs
   through direct eval, load-string, file/namespace loading, and AOT. Each must fail
   visibly; complete-form controls must pass. Keep useful test-discovery sentinels
   even if the extra JVM syntax cross-check becomes unnecessary.
6. Run the full default suite and AOT with the configured binary. Report reader
   compatibility separately until it is actually restored; skips are not passes.
   Update requirement/scenario status and these notes only from verified evidence.

For #808, direct and apply unary minus on `Long/MIN_VALUE` both returned the same
negative integer at source revision `bdd8268c9cb3acf369f0854bada47af79d1d673d`;
the independent JVM Clojure control threw `ArithmeticException`. `vm.NumNeg` uses
unchecked host negation for Int. Revisit checked-error compatibility after the
upstream fix, preserving normal/unchecked/promoting arithmetic distinctions.
Keep the fan-in minimum-score regression and direct descending comparison; this
is a boundary-safe algorithm, not a workaround to remove when overflow starts
throwing correctly.

Detailed reproducers and current limitations:

For #810, `(let [xs (map identity [1 2]) ys [1 2]]
[(= xs ys) (= ys xs) (= {:options xs} {:options ys})
(= {:options ys} {:options xs})])` returns `[true true true false]` in the
configured local let-go binary at the same source revision above. JVM Clojure
returns true for both nested-map operand orders. Cover vectors of nested maps
and complete recorded option records as well as the minimal scalar example.
The test workaround preserves all fields; it is not evidence of full nested
equality compatibility.

[reader](let-go-reader-compatibility.md),
[future errors](let-go-future-compatibility.md), and
[native supervision](let-go-supervision-compatibility.md).

## HTTP cancellation: #816

[Native HTTP scope cancellation](let-go-http-cancellation.md) now has real
loopback evidence, tracked as [nooga/let-go #816](https://github.com/nooga/let-go/issues/816).
`http/request` does not attach its invoking scope context. A held request remains
active after scope close; public Attractor generation returns `:abort` while its
HTTP worker remains live. Both probes explicitly release/drain during cleanup.

After the runtime fix, rerun both `test/probes/http_scope_cancellation_check.lg` and
`test/probes/http_llm_cancellation_check.lg` against fresh instances of the bounded
`test/probes/http_cancellation_server.go` fixture. Require server-observed cancellation
and zero live workers before fixture release, not just a caller-side error.
Attractor's `controlled-invoke` and stream-monitor ownership were repaired on
2026-09-08 (`src/attractor/operation_owner.lg`; evidence in
[LLM operation ownership](llm-operation-ownership.md)), with held-body and
stream coverage in `test/probes/llm_ownership_http_check.lg`. The owner joins provider
work indefinitely, which is only safe because native HTTP is now cancellable.

## JSON string keys: #817

At local source revision `bdd8268c9cb3acf369f0854bada47af79d1d673d`,
`(json/write-json {"key" "value"})` emits a key containing literal quote characters;
reading it back does not equal the original map. `fromMapValue` uses the printed
`k.String()` representation rather than the underlying Go string for string keys.
Tracked in [nooga/let-go #817](https://github.com/nooga/let-go/issues/817).

`test/attractor/stream_terminal_error_test.lg` temporarily converts its fixed
fixture keys to keywords before JSON encoding. After the configured binary is
fixed, verify nested string-key roundtrips and escaped/Unicode keys, remove that
fixture-only conversion, and rerun the terminal-error corpus and bundle. Do not
apply keywordization as a general lossless workaround for arbitrary keys.

## Lazy-seq realization context: #829

At local checkpoint `7ea895f4502845248125b5fb2af01e5686048cde`, a `lazy-seq`
thunk realized inside a `future` runs under `RootExecContext`, not the realizing
goroutine's context: `LazySeq.sval` calls `fn.Invoke(nil)`, and `scope-open` on the
main thread mutates the root context's scope field in place. Closing an unrelated
sibling scope therefore cancels blocking natives (sleep, channel ops, scoped HTTP)
inside a lazy seq owned by a different, still-live scope. Tracked in
[nooga/let-go #829](https://github.com/nooga/let-go/issues/829).
Reproducer: `test/probes/lazy_scope_isolation_check.lg` (exits 1 while the bug is present).

Application impact: bounded discovery (`capacity/call!`) opens a child scope per
probe, and that close interrupted lazy stream HTTP work in the native ownership
check. Only diagnostic state polls in `test/probes/llm_ownership_http_check.lg` were
switched to direct `http/request`; production discovery was NOT removed. After the
runtime fix, rerun the reproducer (expect exit 0) and the native ownership check,
then reassess whether stream consumers still need the owner coordinator to hold
a stable scope between reads. Keep operation-lifetime ownership regardless: it is
the Attractor design, not a workaround for this bug.

## Scope cancellation predicate: #830

Local runtime `425d8461` on the same workspace adds `scope-cancelled?`
([nooga/let-go #830](https://github.com/nooga/let-go/issues/830)). Blocking
natives return early and silently on cancellation, so a coordinator parked on
`sleep` cannot otherwise tell waking from cancellation; the operation owner's
`checked` uses the predicate to drain when its parent scope closes without any
control signal (`parent-scope-close-drains-idle-coordinator-without-control-signal`).
When upstream ships a predicate or makes `sleep` throw, switch to the released
form and rerun the owner and ownership checks. Do not replace it with a timing
heuristic: `System/nanoTime` is wall-clock here.

## Streamed http/serve bodies: #831

The same local runtime streams channel and lazy-seq response bodies with a flush
per element ([nooga/let-go #831](https://github.com/nooga/let-go/issues/831)).
`test/fixtures/context_discovery_server.lg` relies on it for `held-body`, `held-json`,
`sse` and `tool` scenarios; the released runtime would buffer those bodies and
the held scenarios would degrade into held headers. Handlers still cannot observe
client disconnect, so native checks witness cleanup client-side (transport exit,
body closed once, zero live workers) rather than server-side.

## bound-fn* scope detachment: #832

`bound-fn*` wrappers were context-free natives invoking through a fresh
`ExecContext` whose nil scope normalises to the root scope, so work inside a
bound fn escaped the caller's structured-concurrency scope
([nooga/let-go #832](https://github.com/nooga/let-go/issues/832)). The local
runtime makes the wrapper context-aware and inherits the invoking scope. The
operation owner wraps every submitted job with `bound-fn*` so tool callbacks and
custom clients see the caller's dynamic bindings; with the released runtime those
jobs would silently become uncancellable. After the upstream fix, rerun
`jobs-see-caller-bindings-and-remain-owned` and the shared/native ownership checks.

## eval execution context: #833

`eval` built its frame with a nil execution context, so evaluated code ignored
the caller's bindings and scope ([nooga/let-go #833](https://github.com/nooga/let-go/issues/833)).
The local runtime (`425d8461`) runs the compiled form in the caller's context
via `vm.NewFrameIn`. The hub's `:eval/submit` relies on it to capture printed
output with `with-out-str` inside the evaluation future; with the released
runtime that output would leak to the hub process's stdout. Note also that
`*ns*` is process-global and `binding` does not restore it, so the hub switches
namespaces explicitly with `in-ns` and restores in `finally`; evaluations are
serialized. After the upstream fix, rerun `test/runner.lg attractor.hub-console-ops-test`.

## Codex subprocess interop: #813, #814, #815

Findings from 2026-09-07 on the Codex app-server transport:

- [#813: mutable byte-array interop](let-go-byte-array-interop.md): reflected
  Go slice arguments are copied, so `.Read` does not mutate the caller's buffer.
  Buffered `ReadByte` is a verified possible workaround for bounded framing.
- [#814: boxed pointer field lookup](let-go-boxed-pointer-fields.md): lookup of
  `exec.Cmd.Process` fails without pointer dereference. Keep exact-child forced
  shutdown unverified until this or an equivalent owned-process path is tested.

These are Go interop issues, not a reason to introduce JVM-shaped APIs. No
runtime source changes accompany these findings.

- [#815: JSON integer precision](let-go-json-integer-precision.md): float64
  decoding rounds valid int64 values above 2^53. Preserve a large-ID regression
  for Codex RPC; small locally generated IDs do not fix server-supplied IDs.

## Data reader mode: #801, #823

The local runtime's `clojure.edn/read-string` and `edn/read-all-string` read
with Clojure data semantics (metadata attached, real sets, discards splice
nothing, duplicate keys and set elements rejected); code reading keeps the
compiler's `(with-meta ...)` and `(hash-set ...)` forms. An approach note was
left on #801. `attractor.composition/read-mapping` and the artifact store's
round-trip validation depend on it; a released runtime without the mode would
reject metadata and discards in mappings and set-valued artifacts again.

## HTTP client timeouts and line-seq errors: #844, #845

The local runtime's `http/request` honours `:timeout {:connect s :request s
:stream_read s}` (a bare number or `:timeout_ms` is the request scope): a
pooled transport per dial timeout, a context deadline for the whole cycle
(headers only for `:as :stream`), and a per-read gap timer on the streamed
body that cancels the request when a chunk is late (the first chunk is
bounded by the request scope, since a model may process a long prompt before
its first token). Errors are
`http <scope> timeout after <d>`
([nooga/let-go #844](https://github.com/nooga/let-go/issues/844)).
`io/line-seq` now ends a sequence only on `io.EOF`; any other read error is
thrown when the sequence is realized
([nooga/let-go #845](https://github.com/nooga/let-go/issues/845)).
`attractor.llm/transport-failure` classifies those messages (connect and
stream_read: `:network`, retryable; request: `:request-timeout`), the
adapters send `default-adapter-timeout` (10s / 120s / 30s) unless a request
carries `:adapter_timeout`, and `llm_transport_test.lg` proves the three
scopes against the loopback fixture. A released runtime without #844 would
silently ignore the timeouts again; without #845 a stalled stream would look
like a clean end and be reported as a malformed body.

## Upstream pull requests: #848 to #856

The runtime fixes on the fork branch `fix/http-scope-cancellation` were first
proposed together as nooga/let-go #847. That PR was closed on 2026-09-11 in
favour of one PR per issue, each branched from current upstream `main` with
its own test and its own `make generate` commit:

| PR | Issue | Change |
|---|---|---|
| [#848](https://github.com/nooga/let-go/pull/848) | #816 | http clients inherit the caller's scope cancellation |
| [#849](https://github.com/nooga/let-go/pull/849) | #828 | http clients accept an empty `:headers` map |
| [#850](https://github.com/nooga/let-go/pull/850) | #830 | `scope-cancelled?` |
| [#851](https://github.com/nooga/let-go/pull/851) | #831 | streamed `http/serve` bodies |
| [#852](https://github.com/nooga/let-go/pull/852) | #832 | `bound-fn*` keeps the invoking scope |
| [#853](https://github.com/nooga/let-go/pull/853) | #833 | `eval` in the caller's context |
| [#854](https://github.com/nooga/let-go/pull/854) | #801, #823 | EDN data reading |
| [#855](https://github.com/nooga/let-go/pull/855) | #845 | `line-seq` surfaces read errors |
| [#856](https://github.com/nooga/let-go/pull/856) | #844 | HTTP timeouts, stacked on #848 |

On 2026-09-11 the maintainer approved #848 to #855 and requested changes
on #856 for two timeout bugs, filed with two lower-priority items as
[nooga/let-go #857](https://github.com/nooga/let-go/issues/857). The two bugs
were a slow dial reported as a connect timeout when the request deadline had
fired, and a sticky `gapReader` flag that turned a later end of stream into
"stream_read timeout after 0s". Both are fixed on #856 with regression tests.
Items 3 and 4 of #857 (`:stream_read` alone leaving the first chunk
unbounded; `http/get` and `http/post` ignoring `:timeout`) await the
maintainer's decision.

Each new test fails on `main` without its change and passes with it. Every
branch passes `go test ./...` except `TestCustomMain`'s "versioned fork
replace is reproduced, offline" subtest, which fails identically on untouched
upstream `main` in this environment. Merging one PR changes the generated
manifests the others also regenerate, so each later merge needs a fresh
`make generate`. Until they merge, build the runtime from the fork branch as
the README describes.

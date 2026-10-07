# Let-go Runtime Issues — Consolidated

## Atom Update Gaps (#824)

# Atomic update contract reproductions

Tracked as [let-go #824](https://github.com/nooga/let-go/issues/824).

Observed with local `lg dev (bdd8268)`, independently compared against JVM
Clojure. These are runtime bugs encountered while repairing a shared Attractor
QueueInterviewer; no local runtime changes were made.

## swap-vals! returns an old value from before the committed retry

```clojure
(let [a (atom 0) once (atom true)]
  (prn (swap-vals! a (fn [x]
                       (when (compare-and-set! once true false)
                         (reset! a 10))
                       (inc x)))))
```

Local let-go returns `[0 11]`; JVM Clojure returns `[10 11]`. Both exit zero.
The deliberately reentrant mutation forces a retry without timing-dependent
threads. The returned pair must describe the successful atomic transition, not
a snapshot from before another update.

In local `pkg/rt/lang.go`, `swap-vals!` calls `at.Deref()` separately before
`at.Swap(...)`. The old value must instead come from the same successful commit
inside the atom implementation. This can otherwise make a queue return an answer
that another caller already removed.

## compare-and-set! fails on an unchanged vector identity

```clojure
(let [v [1 2] a (atom v)]
  (prn (compare-and-set! a v [2])))
```

Local let-go exits 1 with `runtime error: comparing uncomparable type
vm.ArrayVector`; JVM Clojure returns `true`. The exact snapshot identity is reused,
so no structural-versus-identity equality ambiguity is involved.

Local `pkg/vm/atom.go` compares interface values using `a.val != oldVal`. An
ArrayVector is not Go-comparable. CAS must safely perform let-go value identity
comparison rather than requiring underlying Go comparability.

Restore coverage for successful and failed CAS on collection identities and
retrying/concurrent swap-vals! pairs. Do not replace CAS identity with structural
equality. Attractor can temporarily guard dequeue using CAS on a boolean lock;
remove that workaround only after the native atomic-update contracts pass.

---

## Boxed Pointer Field Lookup (#814)

# Boxed pointer field lookup does not dereference the receiver

Upstream: https://github.com/nooga/let-go/issues/814

Observed 2026-09-07 with the local let-go binary; user-owned checkout HEAD was
`bdd8268c9cb3acf369f0854bada47af79d1d673d`, potentially with uncommitted changes.

## Reproducer (does not launch a process)

```clojure
(get (os/exec "/bin/true") "Process")
```

Expected: nil, because the unstarted Go `exec.Cmd` has a nil `Process` field.
Actual: `reflect: call of reflect.Value.FieldByName on ptr Value`.

## Cause and impact

`pkg/vm/boxed.go`, `Boxed.ValueAtOr`, invokes
`reflect.ValueOf(n.value).FieldByName(name)` without dereferencing a pointer to
the containing struct. `os/exec` returns boxed `*exec.Cmd`, so field access fails
before conversion of the field value. This also prevents accessing the exact
owned process handle for `.Kill` when implementing bounded subprocess shutdown.

Potential repair: safely dereference non-nil pointers before looking up exported
struct fields. Handle nil pointers, missing fields, non-struct receivers and
unexported fields without reflection panics. Add tests for the intended lookup
default and actual started-process handle; do not broaden this into new host
field syntax unless separately intended.

No let-go source was modified. The basic stdin/stdout duplex probe remains
valid; it proved only graceful close and wait. Attractor must not claim bounded
forced shutdown until a tested exact-process termination path exists. Avoid
process-name matching or killing unrelated Codex instances as a workaround.

---

## Byte Array Interop (#813)

# Mutable byte-array copying during Go interop

Upstream: https://github.com/nooga/let-go/issues/813

Observed 2026-09-07 with the local let-go binary; checkout HEAD was
`bdd8268c9cb3acf369f0854bada47af79d1d673d` (user-owned checkout may contain edits).

## Reproducer

```clojure
(require '[io :as io])
(let [r (io/string-reader "ABC")
      b (byte-array 3)]
  (println :n (.Read r b) :actual (vec b) :expected [65 66 67]))
```

Actual: `:n 3 :actual [0 0 0] :expected [65 66 67]`.
The reader consumes the input, but mutations to the Go byte slice are not
visible in the original let-go array. The same result occurs with `.Read` on a
child process stdout pipe; this is not a subprocess-specific problem.

## Cause

`pkg/vm/native_func.go` function `boxArgForReflect` handles slice/array targets
by treating every `Sequable` as a sequence to copy with `unboxSliceInto`.
`TypedArray` implements `Sequable`, so its existing mutable Go slice returned
by `Unbox()` is not passed through. A correctly typed mutable byte-array should
retain its backing storage for calls whose contract mutates that buffer.

Potential upstream repair: preserve compatible typed-array backing slices
before generic sequence conversion. Keep vector/list conversion behavior and
add regression coverage for byte-array identity/mutation and other array types.
No runtime source was modified in this investigation.

## Attractor workaround and return point

Buffered single-byte reads do not require caller-owned mutable buffers:

```clojure
(let [r (.Buffered (io/string-reader "ABC"))]
  [(.ReadByte r) (.ReadByte r) (.ReadByte r)])
;; verified result: [65 66 67]
```

Use this boundary when implementing bounded Codex frame accumulation; do not
replace bounded framing with an unbounded line reader. Revisit chunked reads
after an upstream fix, with a regression proving the caller's array changes
and a split-UTF8 protocol test. EOF/error propagation and AOT remain separate
transport verification obligations.

---

## Follow-ups & Upstream Tracking

# Upstream let-go follow-ups

2026-09-12 release recheck: GitHub's latest release remains
[v1.12.2](https://github.com/nooga/let-go/releases/tag/v1.12.2), published July 20.
PRs #848–#855 have merged, while #856 remains open. The earlier statement below
that those eight PRs still await merging is historical. Merged changes are not
yet evidence of a released runtime containing them. The reproducible build now
pins fork revision `46244c4fa8169b8138aa1c29f31c8a6102ed1755` and applies both
tracked runtime patches; see [runtime build evidence](runtime-audits.md).

2026-09-12 historical state: the local runtime needed the JSON string-key fix
recorded in [runtime build evidence](runtime-audits.md). The patch directory has
since been removed; `lgx.edn` records the current release pin. HTTP question IDs and
context keys previously included reader quotes. The native compiled-server probe
now passes with that patch. Empty lazy sequences still serialize incorrectly as
`[null]` in the observed runtime; the pipeline listing now constructs a vector.

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

[reader](let-go-runtime-issues.md),
[future errors](let-go-runtime-issues.md), and
[native supervision](let-go-runtime-issues.md).

## HTTP cancellation: #816

[Native HTTP scope cancellation](let-go-runtime-issues.md) now has real
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

- [#813: mutable byte-array interop](let-go-runtime-issues.md): reflected
  Go slice arguments are copied, so `.Read` does not mutate the caller's buffer.
  Buffered `ReadByte` is a verified possible workaround for bounded framing.
- [#814: boxed pointer field lookup](let-go-runtime-issues.md): lookup of
  `exec.Cmd.Process` fails without pointer dereference. Keep exact-child forced
  shutdown unverified until this or an equivalent owned-process path is tested.

These are Go interop issues, not a reason to introduce JVM-shaped APIs. No
runtime source changes accompany these findings.

- [#815: JSON integer precision](let-go-runtime-issues.md): float64
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

---

## Future Compatibility

# Future exception compatibility

Confirmed on 2026-09-06 using the configured local let-go binary and installed
JVM Clojure. This is separate from the [reader findings](let-go-runtime-issues.md).

In let-go:

```clojure
(let [f (future (throw (ex-info "future-probe" {:probe true})))]
  (try
    (println {:returned (deref f 1000 :timeout)})
    (catch Object e (println {:caught (ex-data e)}))))
```

Actual output is `{:returned nil}`, exit 0. The exception is not propagated.

In JVM Clojure, the same future/deref operation with a `Throwable` catch reports
`java.util.concurrent.ExecutionException`, whose cause has `{:probe true}` as
its exception data. `shutdown-agents` was called after the probe to release the
JVM executor threads.

The inspected local source, `pkg/rt/lang.go`'s `futureStar`, invokes the worker and
explicitly delivers `vm.NIL` when invocation returns an error. This makes a failed
future indistinguishable from a successful nil result at dereference.

Attractor's parallel coordinator must therefore catch worker exceptions inside
the future and return explicit tagged result/error records. Coordinator cleanup
and error propagation cannot depend on native future dereference rethrowing.
An error record is not itself proof of worker termination: join the actual future
before reusing the slot, and use native scope supervision to drain its descendants
before returning from the invocation.

## Native supervision is available

Let-go provides `with-scope`, `scope-open`, `scope-close!`, `scope-live`, and
`scope?`, backed by `vm.Scope`. These supervise worker lifetimes and cancellation;
they are not absent merely because Clojure-compatible futures lose exceptions.
The user correctly directed this implementation toward those native primitives.

A local runtime probe opened a scope, launched a future blocked on `<!`, and
closed the scope with `scope-close! scope 0`. The worker's finally block ran and
`scope-live` returned zero afterward. A launcher closure created before opening
the scope still inherited it when invoked within the owner's execution context.
Zero means indefinite drain; the default `with-scope` five-second warning-and-return
behavior is not sufficient for Attractor's no-late-work guarantee. The coordinator
must close its scope, never a worker tracked inside that same scope.

Native `pmapv` also preserves Go worker errors and returns `vm.NIL, err` after
joining its workers. It does not expose the configurable scheduling bound and
early-stop policy this handler needs. The narrower future error finding remains
valid; it does not imply that all let-go concurrency APIs discard errors.

Tracked upstream as [let-go #805](https://github.com/nooga/let-go/issues/805).
The user authorized filing bugs and evolving let-go as needed; this is a removable
workaround, not a permanent architectural constraint. No let-go source changes
were made as part of this investigation. This workaround does not change the
separate failing Clojure-reader acceptance requirements.

---

## HTTP Cancellation

# Native HTTP scope cancellation gap

## Local runtime fix, 2026-09-08

Discovery follow-up checkpoint:
`7ea895f4502845248125b5fb2af01e5686048cde` in the same isolated workspace.
It adds `:scope-cancellation true` metadata to the three HTTP client vars, so
Attractor can reject unsupported runtimes before probing. It also fixes empty
client headers maps, reported as [#828](https://github.com/nooga/let-go/issues/828):
the native loop treated an empty sequence sentinel as a map entry and dereferenced
nil. Let-go loopback tests exercise `{}` through request/get/post.

Unread, unclosed streamed bodies are now covered by
`TestHTTPClientScopeCancelsUnreadStream`, including server-observed cancellation;
20 race repetitions passed. After the latest empty-header fix, full rt/vm/api
tests and vet passed, as did five race repetitions of HTTP client scope tests
and the API catchability test. These are local runtime fixes, not an upstream
release. The earlier checkpoint and evidence below are retained as history.

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

Run `go run test/probes/http_cancellation_server.go` from this worktree. It prints a
loopback URL. In another shell run one of the following, replacing URL with that
address. Use a fresh fixture server for each check.

```sh
/Users/ndn/development/let-go/lg test/probes/http_scope_cancellation_check.lg URL
/Users/ndn/development/let-go/lg -source-paths src test/probes/http_llm_cancellation_check.lg URL
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

---

## JSON Integer Precision

# JSON integer precision loss

Upstream: https://github.com/nooga/let-go/issues/815

Observed 2026-09-07 with the local let-go binary (user-owned checkout HEAD
`bdd8268c9cb3acf369f0854bada47af79d1d673d`, potentially with local edits).

```clojure
(require '[json :as json])
(get (json/read-json "{\"id\":9007199254740993}") "id")
;; actual 9007199254740992, expected 9007199254740993
```

`pkg/rt/json.go` decodes JSON numbers through Go float64 and then converts
integral float64 values to VM integers. Exact integers above 2^53 can already
have been rounded before that conversion. This value is within signed int64
range, so the loss is not an unavoidable VM integer-range limitation.

Consider `json.Decoder.UseNumber` with explicit exact int64 conversion, retaining
intentional decimal/exponent behavior and defining out-of-range errors. Tests
should cover 2^53 boundaries, signed int64 limits, negative values, decimal and
exponent forms, and malformed inputs. No runtime source was modified here.

## Attractor return point

Codex's installed schema permits signed int64 JSON-RPC IDs. Generating small
client IDs does not solve incoming server request IDs: a rounded incoming ID
cannot safely be echoed back. Request correlation must not claim the full ID
contract until this is fixed or a verified exact decoder is used. Add a large-ID
wire regression when implementing `attractor.codex.rpc`; framing success alone
does not establish lossless numeric decoding.

---

## Reader Compatibility

# Clojure reader compatibility findings

Resolved locally on 2026-09-08: the local let-go runtime (`425d8461`) reads
`clojure.edn/read-string` and `edn/read-all-string` in a data mode with Clojure
semantics, and `attractor.composition/read-mapping` reads mappings natively.
The five deferred acceptance cases now live in
`test/attractor/composition_contract_test.lg` and pass; the `compat/` suite and
the temporary scanner are removed. Upstream #801 and #823 remain open for the
released runtime; see `let-go-followups.md`. The original findings follow.

Additional set-literal data reading is tracked in [let-go #823](https://github.com/nooga/let-go/issues/823):
the local reader returns a `hash-set` call rather than a set, so artifact
round-trip validation rejects set-valued data. See `let-go-set-reader-gap.md`
for the bounded let-go/JVM comparison and restoration criteria. No evaluation
workaround is permitted.

Observed 2026-09-06 using `/Users/ndn/development/let-go/lg` and the installed JVM `clojure`. These are runtime differences, separate from Strange Lettractor's overly restrictive mapping scanner. The user requires Clojure reader syntax (the superset of EDN), retaining `.edn` filenames.

## Reproduce

Run the same expression with `lg -e` and `clojure -M -e`:

```clojure
(read-string "^{:doc \"mapping\"} {\"a\" \"b\"}")
```

Clojure returns the map `{"a" "b"}`, with metadata `{:doc "mapping"}`. The local let-go reader instead returns the list `(with-meta {"a" "b"} {:doc "mapping"})`; `map?` is false. In let-go's `pkg/compiler/reader.go`, `readMeta` constructs this list rather than attaching metadata to the read value.

```clojure
(read-string "{\"a\" #_[:ignored] \"b\"}")
```

Clojure returns `{"a" "b"}`. The local let-go reader throws `map literal must contain even number of forms`. A leading discard before the map does work in the same local binary.

The [Clojure reader reference](https://clojure.org/reference/reader) specifies that metadata attaches to the following form and that `#_` completely skips its following form. Both expected results were also verified by executing the expressions in JVM Clojure, not inferred solely from documentation.

## Temporary implementation and remaining requirement

The upstream defects are tracked in [let-go issue #801](https://github.com/nooga/let-go/issues/801). The user authorized a temporary mapping subset so Attractor development can continue. No local let-go files were changed.

The current application scanner accepts ordinary string-to-string maps, whitespace, commas, comments, and native string escapes including Unicode. It rejects **all** reader discards and metadata, even leading/trailing discards that the runtime can already read. This is an explicit interim application limitation, separate from the two runtime defects above. Unsupported forms produce `subpipeline_config` errors; reading never evaluates code. Full Clojure reader support remains unmet.

Five desired acceptance cases are preserved outside default discovery in `compat/clojure_reader_mapping_test.lg`. From the project root, run:

```sh
/Users/ndn/development/let-go/lg -source-paths src:. compat/run_mapping.lg
```

Current result: 1 test, 5 failed assertions, exit 1. These are deferred failing requirements, not skipped or passing tests. Default composition tests instead verify the temporary rejection behavior and supported Unicode decoding.

Restore full support by fixing/verifying #801, replacing the scanner with native reader integration that safely consumes the whole input, and making the deferred command pass. Then move those acceptance cases back into default discovery, replace the temporary rejection assertions, and remove the exception from the design/plan. An upstream fix alone does not change the application scanner. `read-string` reading only the first form is normal Clojure behavior; the application must separately enforce exactly one resulting map without evaluating forms.

## Unfinished trailing source forms

Separately confirmed on 2026-09-06 with the local let-go checkout at
`bdd8268c9cb3acf369f0854bada47af79d1d673d`:

```sh
/Users/ndn/development/let-go/lg -e '(println "before") (println "unfinished"'
clojure -M -e '(println "before") (println "unfinished"'
```

The let-go command prints `before` and `nil`, then exits 0. JVM Clojure prints
`before`, reports `EOF while reading`, and exits 1. The valid control with the
missing closing parenthesis restored prints both strings in let-go.

The same difference occurs when evaluating:

```clojure
(load-string "(println :before) (println :unfinished")
```

In the inspected source, `pkg/compiler/compiler.go`'s `CompileMultiple` loop
stops on `isErrorEOF` without distinguishing end-of-input between forms from
end-of-input inside an unfinished form. This is different from `read-string`
legitimately returning only the first form. It is also separate from the
metadata/discard defects tracked in #801. The unfinished-form finding is now
tracked separately as [let-go #807](https://github.com/nooga/let-go/issues/807).

An unfinished trailing test definition can therefore disappear from discovery
without making the test command fail. Check discovered test counts as well as
failure counts, and verify newly added tests actually run. No local let-go files
were changed for this investigation.

---

## Set Reader Gap (#823)

# Set literals read as executable forms rather than set values

Tracked in [let-go #823](https://github.com/nooga/let-go/issues/823).

Observed with local `lg dev (bdd8268)` while exercising artifact round trips.
This is distinct from #810's nested sequential equality issue: the reader returns
the wrong value type. #801 covers metadata/discards; this adds a set-literal case.
The current upstream HEAD has not been tested; no local runtime edits were made.

Run with `lg -e` and JVM `clojure -M -e`:

```clojure
(require (quote [clojure.edn :as edn]))
(let [v (edn/read-string "#{:a :b}")]
  (prn {:read v :set? (set? v) :equal (= #{:a :b} v)}))
```

Local let-go: `{:set? false, :read (hash-set :b :a), :equal false}`.
JVM Clojure: `{:read #{:b :a}, :set? true, :equal true}`.
Element print order is immaterial; the list-versus-set distinction is the defect.

Local `pkg/compiler/reader.go`'s `readSet` constructs a list headed by `hash-set`.
That lowering form may be useful to the compiler, but must not escape a data read
as the result of a set literal. Expected: a set value, including nested maps and
vectors, without evaluating the result.

Attractor's artifact store correctly rejects this failed non-evaluating round
trip with `:unsupported-artifact-value`. Do not use `eval` as a workaround.
Current store evidence uses supported scalar/vector/map values; set-valued
artifact conformance remains deferred until the reader is corrected. Restore
coverage for both `clojure.edn/read-string` and core `read-string`, direct and
nested sets, and artifact store/retrieve after that fix.

---

## Supervision Compatibility

# Native scope ownership boundaries

Verified with the configured local let-go binary on 2026-09-06. Native `go` and
`future` inherit the calling execution context's scope. Closing their owning
scope cancels native blocking operations and waits for registered descendants.

However, `async/map` launches its worker using the process-root
`vm.Goroutines.Go` in `pkg/rt/async.go`, rather than `ec.Scope().Go`.

```clojure
(require '[async :as a])
(let [input (a/chan)
      calls (atom [])
      s (scope-open)
      output (a/map (fn [x] (swap! calls conj x) x) [input])]
  (scope-close! s 0)
  (println {:live-after-close (scope-live s) :calls-before @calls})
  (a/>!! input :after-close)
  (println {:result (a/<!! output) :calls-after @calls})
  (a/close! input)
  (a/<!! output))
```

Observed output:

```clojure
{:calls-before [], :live-after-close 0}
{:result :after-close, :calls-after [:after-close]}
```

The callback runs after its lexical scope has closed. The probe closes the input
and observes output EOF, so it does not leave its root-owned worker blocked.
Other async helpers also contain root-spawn sites, but this behavior probe
establishes only `async/map`; do not infer identical behavior for every helper.

Attractor's parallel scheduler uses verified scoped futures and drains their
registered subtree. This cannot supervise work a custom callback launches through
a root-owned helper or another detached host mechanism. Arbitrary helper-spawned
descendant cleanup remains unproved until the upstream ownership gap is addressed.
Tracked upstream as [let-go #806](https://github.com/nooga/let-go/issues/806).
The user authorized filing bugs and evolving let-go as needed. Fixing native
ownership and rerunning these probes is the intended resolution, not retaining
this limitation permanently. No let-go source changes were made during this
investigation.

---

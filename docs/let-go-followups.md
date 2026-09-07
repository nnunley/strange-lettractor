# Upstream let-go follow-ups

These are temporary workarounds or unproved runtime guarantees, not permanent
design choices. Revisit this checklist whenever updating the local let-go checkout
or binary. An issue being closed is not sufficient: verify the fix is present in
the actual configured compiler and rerun the relevant behavior checks.

| Issue | Current application seam | Revisit when fixed |
|---|---|---|
| [#801: metadata and map discards](https://github.com/nooga/let-go/issues/801) | `src/attractor/composition.lg` mapping scanner; `compat/clojure_reader_mapping_test.lg` | Restore native Clojure-reader acceptance and remove the ordinary-map restriction. |
| [#805: future exceptions](https://github.com/nooga/let-go/issues/805) | `src/attractor/handlers.lg` parallel worker error records and coordinator collection | Reassess explicit exception transport; preserve cleanup-before-propagation and ordered results. |
| [#806: async helper scope ownership](https://github.com/nooga/let-go/issues/806) | Parallel invocation scope; `test/attractor/parallel_join_contract_test.lg` | Add real async-helper descendant cancellation/join evidence and remove the documented ownership exception only when proved. |
| [#807: unfinished trailing forms](https://github.com/nooga/let-go/issues/807) | Test discovery checks and independent JVM reader checks | Verify malformed sources fail visibly across evaluation, namespace loading, and AOT; then reassess the extra manual syntax cross-check. |
| [#808: unary negation overflow](https://github.com/nooga/let-go/issues/808) | `src/attractor/fan_in.lg` descending score comparison | Verify ordinary `(- Long/MIN_VALUE)` and first-class/apply calls throw overflow. Retain direct comparison: Clojure also cannot safely negate this score. |
| [#809: UUID string coercion](https://github.com/nooga/let-go/issues/809) | Unique manager-test fixture names in `test/attractor/engine_test.lg` | Verify `str` returns canonical UUID text while `pr-str` and direct UUID printing remain tagged. Reassess fixture-name sanitization separately from general path escaping. |
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

After the runtime fix, rerun both `dev/http_scope_cancellation_check.lg` and
`dev/http_llm_cancellation_check.lg` against fresh instances of the bounded
`dev/http_cancellation_server.go` fixture. Require server-observed cancellation
and zero live workers before fixture release, not just a caller-side error.
Then address Attractor's `controlled-invoke` and stream-monitor ownership and
extend coverage to held response bodies and streams. Adding an indefinite join
before the HTTP request is cancellable would introduce an unbounded wait.

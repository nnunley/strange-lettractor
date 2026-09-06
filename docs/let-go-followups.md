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

Detailed reproducers and current limitations:
[reader](let-go-reader-compatibility.md),
[future errors](let-go-future-compatibility.md), and
[native supervision](let-go-supervision-compatibility.md).

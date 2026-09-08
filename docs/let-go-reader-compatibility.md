# Clojure reader compatibility findings

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

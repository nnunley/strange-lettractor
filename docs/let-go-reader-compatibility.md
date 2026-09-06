# Clojure reader compatibility findings

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

## Implementation status

- Do not use `eval` to compensate for the metadata result or narrow accepted syntax to conceal either difference.
- Fixes in the separate local let-go repository await user authorization. No runtime files were changed for these findings.
- Mapping configuration still needs native-reader parsing and safe whole-input consumption. Its current scanner does not meet the clarified contract.
- `read-string` reading only the first form is normal Clojure behavior, not a compatibility bug; the application must separately enforce exactly one resulting value.
- The mapping regression tests are intentionally red pending the runtime/parser work. This is not completion of ITER-0005.

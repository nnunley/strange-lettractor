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

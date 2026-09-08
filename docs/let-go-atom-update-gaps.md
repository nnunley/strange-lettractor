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

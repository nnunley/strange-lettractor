# Future exception compatibility

Confirmed on 2026-09-06 using the configured local let-go binary and installed
JVM Clojure. This is separate from the [reader findings](let-go-reader-compatibility.md).

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
before returning or reusing the slot.

The user has been notified. No let-go source changes or upstream issue submission
were made as part of this investigation. This workaround does not change the
separate failing Clojure-reader acceptance requirements.

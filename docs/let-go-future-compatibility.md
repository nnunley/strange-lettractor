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

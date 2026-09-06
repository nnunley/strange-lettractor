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

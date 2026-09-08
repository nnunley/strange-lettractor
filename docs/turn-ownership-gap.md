# Resolved component: stale-turn cancellation across completion callbacks

This is a verified Attractor lifecycle bug, not a new let-go issue or a hook
regression. Track as CAL-OWN-01 / SCN-CAL-TURN-OWNERSHIP. The repair assigns
current ownership on every root admission and atomically claims closure before
backend cleanup. Queued follow-ups retain ownership; stale callers cannot close
or evict a successor. Explicit public session abort/close remains session-wide.

Permanent evidence: `test/attractor/turn_ownership_test.lg`, run with
`/Users/ndn/development/let-go/lg -source-paths src:test dev/turn_ownership_tests.lg run`.
Five tests / 85 assertions pass, including stale cancellation/error, direct
successors, reverse successor-abort isolation, follow-up cancellation cleanup,
and adoption of a newly published but unadmitted session. Impacted tests pass
198/1405; full suite passes 644/5970; standalone bundle and CLI build/help pass.
See `turn-ownership-evidence.edn`. Broader shutdown conformance remains open.

## Historical reproduction

Two bounded diagnostic processes reproduced the same interference against the
hook candidate and pre-hook public checkpoint `f38af57`; both exited zero and
released their workers. This preceded the permanent regression and repair.

Reproduction:

1. Start full-fidelity backend turn A with a cancellation predicate.
2. Gate A's `:processing_end` callback, after the session becomes idle.
3. Admit turn B in the same cached session and gate B's provider completion.
4. Cancel A before releasing either callback/provider gate.

Both versions observed:

```clojure
{:callback_gate true
 :second_admitted true
 :closed_before_release true
 :history ["first" "done" "second"]}
```

After release, the hook candidate's B throws `:cancelled`; baseline B returns an
empty string. Both sessions have been closed by A's stale cancellation monitor.

The session becomes idle in `process-input-cycle!` before its processing-end
callback completes. `run-agent-turn-with-cancellation!` still treats A's admission
token as owned and calls session-wide abort. A's authority needs to be fenced by
the session's **current** invocation, including failure cleanup and cache eviction.
The new hook admission guard protects rejected/pending callers, not this handoff.

The repair preserves completion-callback reentry and follow-up semantics rather
than forbidding the handoff. Source obligations: coding-agent
specification §2.3, §2.8 and graceful shutdown. Broader CAL-LOOP-01/CAL-ERROR-01
remain incomplete even while the default suite is green.

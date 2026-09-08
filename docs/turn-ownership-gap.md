# Pending: stale-turn cancellation across completion callbacks

This is a verified Attractor lifecycle bug, not a new let-go issue or a hook
regression. Track as CAL-OWN-01 / SCN-CAL-TURN-OWNERSHIP. It remains unfixed.

Two bounded diagnostic processes reproduced the same interference against the
hook candidate and pre-hook public checkpoint `f38af57`; both exited zero and
released their workers. No persistent regression has been added yet.

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

Next work: add the gated regression mechanically, then ensure canceling or failing
A cannot close B, abort B's controller, or evict B's cache entry. Preserve supported
completion-callback reentry and follow-up semantics; do not simply forbid existing
behavior without reviewing the session contract. Source obligations: coding-agent
specification §2.3, §2.8 and graceful shutdown. Broader CAL-LOOP-01/CAL-ERROR-01
remain incomplete even while the default suite is green.

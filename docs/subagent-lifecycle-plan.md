# Subagent lifecycle — ITER-0007 component

Source: coding-agent-loop spec §7.2–7.3, §9.1, §9.9 and §9.11; CAL-SUBAGENT-01,
SCN-CAL-SUBAGENTS. This component does not close the full story or iteration.

Baseline at `39338c4`: full suite 667 tests / 6507 assertions / zero failures.
The native public-API probe `dev/subagent_lifecycle_probe.lg run` reproduces:
close returns `:closed`, then provider completion changes the handle to
`:completed` with `:success true`, despite the child remaining closed.
Root cause: unconditionally publishing completion after `process-input!` returns;
there is no subagent-run ownership fence shared with close/admission.
The same probe also confirms a closed parent accepts a fresh spawn: its provider
is called once, wait returns successful output, and the child remains idle.
The probe explicitly closes this orphan after observing it. Parent admission
currently has no lifecycle-state check or coordination with cleanup's child scan.
The completion-event probe confirms an acknowledged queued `send_input` remains
in an idle child's queue while wait returns the predecessor's output. The child
sets itself idle before `processing_end`; the wrapper still says running until
that callback returns, so send chooses a queue no worker will drain.
The first permanent test attempt terminated with a native deadlock (exit 2),
not valid passing/failing assertion totals. Inspection identifies a callback
hazard to verify: nested child→parent event forwarding replaces the single
delivery-session marker; closing the child from the forwarded parent callback
can wait for the child event drainer already on that same call stack. Callback
safety requires accounting for delivery ancestry, not just the innermost id.

## Planned contracts and evidence

1. Closing active children is terminal: late success or error cannot resurrect
   the handle or report a successful cancelled run. Repeated close is safe;
   sending to a closed child rejects without launching work. A completed result
   may remain historical success when the child is closed after completion.
2. Parent shutdown and spawn admission are coordinated: a child either becomes
   registered before shutdown and is cancelled by it, or is rejected without an
   orphaned worker. No child starts after a completed parent shutdown.
   Exercise both orderings with deterministic spawn-vs-shutdown barriers, not
   only a sequential closed-parent check.
3. Accepted send-input messages are not stranded at the child idle/completion
   callback boundary. Concurrent sends do not start competing child loops;
   stale workers cannot overwrite newer results/future handles. Prove the
   boundary with controlled event callbacks rather than timing-only sleeps.
   Send and close share an admission linearization point: if send wins, its
   acknowledged run is owned and subsequently cancelled; if close wins, send
   rejects without launching a worker. Prove both with controlled barriers.
4. Preserve independent histories, normal sequential reuse, depth/turn limits,
   native scoped-command parent cancellation, and root turn-ownership contracts.
5. Wait snapshots the already-published run completion handle under the same
   admission lock. It never observes a publication gap or an older worker after
   a new run has been acknowledged. Messages acknowledged as queued onto a run
   belong to its completion; messages admitted after completion create a new
   run. An already waiting caller continues to await its captured run, not a
   replacement. Prove this through public wait calls with bounded outer worker
   joins, including the send/completion callback boundary. Close from a child
   event callback must return without self-join deadlock. A blocked provider
   still blocks its run's wait until that worker exits; close must not fabricate
   quiescence by prematurely resolving the completion handle.

Use native let-go concurrency and existing lifecycle ownership primitives.
Publish run ownership/wait handles before starting workers; never hold a lock
across provider/environment/user callback execution. Document the implemented
lock ordering and the admission/close linearization points. Do not add an
unconditional synchronous worker join: close called from a child event callback
must not deadlock waiting for itself. Cancellation signalling and worker
quiescence are distinct; bounded tests release controlled providers and join
their actual worker handles. The runtime's uninterruptible-provider limitation
must remain explicit, not hidden behind fabricated wait success.

## Task sequence

- Paired scope review, then permanent public-API red tests for each contract.
- Lifecycle implementation and focused red/green evidence; paired spec and
  quality reviews, resolving findings before freezing sources.
- Impacted agent, loop, ownership, timeout, backend, hook tests; full sentinel
  suite; standalone focused bundle; CLI build/help. One full suite at a time.
- Paired component evidence audit, update requirement/scenario/corpus and log,
  then commit and push reviewed changes. Private `docs/notes.md` stays untouched.

Model/profile override fidelity, working-directory validation, live model
acceptance, other §7 evidence, native-Go AOT parity and full event shutdown
remain separately tracked requirements, not implicitly passed by these tests.

## Verified candidate

Focused and external-directory standalone bundle: 12 tests / 106 assertions.
Impacted agent/engine/execution/hooks/error/ownership: 166/1044. Full default
suite: 679/6613, versus baseline 667/6507; all zero failures and exit 0.
CLI build/help pass. Paired spec and quality reviews (Codex and actual Claude
Code) approve after repairing the turn-count ordering and overlapping-close
cancellation issues and adding public wait/pre-launch admission barriers.
Paired component audit is clean; full story and iteration remain partial.

Completion here is publication after model/loop work and synchronous callbacks
return. The public completion promise is not an OS-thread join handle; tests
prove it cannot report completion while the controlled provider is still held.
No uninterruptible-provider or general shutdown-quiescence claim is made.

# Interactive continual harness

The user approved making Attractor's console own a persistent, harness-enabled
session after reviewing Prime Agent's interactive loop. This iteration also
addresses the reported llama.cpp request of 134,031 tokens against a 131,072-token
context. Normal use must never require a trainer.

## Design

Use the existing console, hub, native agent and ledger. A separate interactive
runner would duplicate ownership; a CLI flag alone would leave input admission
and synchronous refinement broken. Extend the existing path instead.

- Console/host startup enables the harness with a durable, session-specific path.
  `--harness PATH` reopens an explicit ledger; `--no-harness` disables it.
  Automatic refinement is configurable and defaults on for harness-enabled
  interactive sessions. Headless workflow behavior remains explicit in DOT.
- The same native session, history, environment, tools and ledger survive user
  turns. Remote clients inherit host policy; request payloads cannot supply
  executable startup options. A configured ledger cannot have competing live
  owners. Additional sessions get distinct automatic paths, or a clear conflict
  for an already-owned explicit path.
  Canonicalized path ownership is enforced within a host and released after
  failed startup or closed sessions. Sharing a ledger across independent host
  processes is unsupported in this iteration and must be documented.
- Ordinary console input steers busy work at the next safe boundary. `/followup`
  queues input until the current response/tool sequence completes. Accepted input
  must not be lost when admission races final completion. Preserve existing
  reject-while-busy behavior for callers that do not request queuing.
  Queued submissions explicitly return `queued=true` and the owning aggregate
  `turn_id`; they do not invent independent completion promises. The worker must
  drain both queues before publishing that aggregate completion, including input
  accepted after the final tool drain.
- `/harness` exposes path, enabled/frozen status and entry/refinement counts.
  `/refine [instructions]` requests refinement in this same session and reports
  completion/failure through events. Commands work for local and nREPL clients.
- Interactive refinement snapshots trajectory, plans without blocking user work,
  waits for a safe idle boundary, then applies validated edits and persistence.
  Application prevents concurrent turn admission. Cancel/close joins owned work;
  no late edits after closure and no provider call under a session/hub lock.
  Keep existing serialized refinement for batch/co-learning callers.
  Apply checks the ledger snapshot/revision used for planning. If intervening
  edits changed it, reject the stale plan visibly rather than overwrite them.
  Planning is single-flight. Automatic triggers coalesce; additional manual
  requests receive a clear busy result. A pending apply takes priority at the
  next safe turn boundary so continued input cannot starve application.
- Context handling must account for the complete provider-bound request and
  output reserve using the effective model context limit. Compact before overflow
  without losing tool-result pairing or immutable host instructions. Recognize
  llama.cpp's structured context overflow and allow bounded recovery; a prompt
  that cannot fit after recovery must fail clearly rather than retry forever.
  Keep the complete transcript separate from the reduced model context; lifetime
  usage/turn budgets and refinement evidence must not reset during compaction.
  Recovery uses a validated server-reported `n_ctx` when the original configured
  capacity was unknown or larger; test this mismatch explicitly.

## Acceptance

Deterministic public-path journeys prove two conversational turns share memory
and environment; busy steering/follow-ups execute once; refinement planning does
not freeze input; application/cancel/close races preserve ownership; durable
ledger reopening restores behavior; local and attached consoles agree. Reproduce
the supplied context error with a fixture, prove safe compaction/recovery and
bounded failure for irreducible requests. No live model or training call is
required for these tests. Existing user `my-harness.*` files remain untouched.

Persisted ledger reuse does not claim full conversation restoration across host
restarts. Existing session cancellation closes that session; retain and document
that behavior unless a separately verified turn-cancellation mechanism is added.

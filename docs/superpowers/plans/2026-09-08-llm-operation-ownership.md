# LLM Operation Ownership Implementation Plan

> **For agentic workers:** Use subagent-driven-development and test-driven-development.
> Main owns integration/evidence/publication; never read or stage docs/notes.md.

**Goal:** make high-level LLM cancellation own and join provider work without
breaking lazy stream lifetime.

**Architecture:** parent-scoped coordinator, child-scoped demanded jobs, atomic
terminal acknowledgement after resource/worker cleanup. Retain existing API.

**Tech Stack:** let-go supervisor scopes/futures, EDN state, clojure.test, native
HTTP with locally fixed runtime; let-go-owned loopback fixtures.

## Chunk 1: Persistent operation owner

Files: create `src/attractor/operation_owner.lg` and
`test/attractor/operation_owner_test.lg`; focused runner under `dev/`.

- [ ] Map each ownership obligation to a controlled witness test before coding.
- [ ] RED: successful demanded jobs share a child scope without cancellation
  between jobs; creator/cross-thread callers and unrelated futures retain scope.
- [ ] RED: abort/deadline/explicit close cancels and joins before acknowledgement;
  tagged errors survive futures; owned-callback close cannot self-join.
- [ ] Implement coordinator start/invoke/finish/close and attempt lifecycle.
  Keep scope creation/restoration entirely in coordinator execution context.
  No unowned polling future or per-event child-scope teardown.
- [ ] Prove throwing closers and delayed finally blocks cannot bypass drainage;
  terminal election is stable, and retry generation begins only after old join.
- [ ] Run native/bundle tests, inspect code and perform spec then quality review.

## Chunk 2: Shared LLM integration

Files: modify `src/attractor/llm.lg`; extend
`test/attractor/llm_cancellation_ownership_test.lg` and its dev runner.

- [x] Establish fresh sentinel baseline: 758/7146/0 on fixed runtime.
- [x] RED: generate/stream abort and per-step timeout join provider cleanup.
  Current result: 4 tests / 12 passing / 8 failing assertions, zero errors.
- [ ] Wire generate lifecycle, controlled-invoke jobs and lazy stream reads into
  the owner; replace discarded monitoring with coordinator control polling.
- [ ] Preserve structured output, tool rounds, partial response, original errors,
  close registration and public signatures. Guard late registration by attempt.
- [ ] Prove every risk in the design: idle/unconsumed streams, sibling and
  cross-thread use, reentrant close, ready-result/control races, no late output.
- [ ] Run existing llm/tool/agent/stream-error tests and both review stages.

## Chunk 3: Native evidence and publication

Files: extend let-go dev fixtures; update behavior-scenarios/corpus, requirements,
roadmap, progress and iteration log with exact component boundaries.

- [ ] Exercise actual native generate/stream against held headers, bodies and
  SSE chunks for abort, total and per-step deadline. Require independent
  disconnect/cleanup witnesses plus zero workers before terminal publication.
- [ ] Prove normal multi-chunk and tool continuation, no premature socket close,
  and no retry before old attempt drainage. Preserve partial output.
- [ ] Native and outside-checkout bundle checks, full sentinel suite, CLI build/help.
- [ ] Review behavior evidence, commit/push verified component to public
  main/console, verify refs; preserve other dirty work and private notes.

Runtime for commands:
`/Users/ndn/development/attractor/.worktrees/let-go-http-cancellation/build/lg`.
Focused RED command:
`RUNTIME -source-paths src:test test/runner.lg attractor.llm-cancellation-ownership-test`.
Full command: `LGX_LG=RUNTIME lgx test` (substitute the exact executable above).

## Audit notes

The citation script returned "all 0 cited stories" because its naming pattern
does not recognize this project's IDs; that output is not citation proof.
Manual reconciliation confirms ULLM-CANCEL-01/ERROR-01 are partial, assigned to
ITER-0010, with no done claims or duplicate pending assignment. ITER-0011 client/
adapters, ITER-0012 native/live parity, ITER-0013 reader remain downstream/open.
The shared PAR templates referenced by the iteration skill are missing locally;
two independent scope reviewers used the available checklist. Reviewer B's
initial REVISE was resolved by the persistent coordinator and attempt-generation
design, followed by explicit APPROVE. Do not mark the full iteration done from
this ownership component: adapter timeout distinctions and full error matrix
remain required.

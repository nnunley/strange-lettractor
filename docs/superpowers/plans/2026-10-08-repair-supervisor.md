# Framework repair supervisor implementation plan

**Goal:** Automatically triage framework failures with a separately configured stronger model and prepare tested Git repair commits. Activation remains an explicit console action; normal harness operation needs neither repairs nor training.

**Architecture:** Capture structured tool/session incidents in agent events. A hub-owned supervisor deduplicates and queues bounded incident snapshots, calls a configured triage model, and routes actionable framework defects to an isolated coding worker. The worker uses a Git worktree under the configured repository's ignored run directory, reproduces the issue with a new regression test before implementation, verifies with trusted host commands, requests independent review, and commits successful repairs. Original checkout and running binary remain unchanged until explicit activation. No automatic replay of failed operations.

**Tech stack:** let-go, existing LLM client and coding sessions, operation-owner scopes, Git, shared console dispatcher.

## Chunk 1: implementation and verification

- [ ] Preserve exception message/category/data, cwd, tool arguments, bounded history, and child delegation context in error events. Test actual missing-file and delegated reads without path guessing.
- [ ] Add `src/attractor/repair.lg`: validate trusted configuration, bound/deduplicate incidents, serialize background triage/repair, enforce timeout and attempt limits, route non-code remedies back as advisory context, retain compact durable status. Test malformed triage, missing paths, duplicate incidents, cancellation, recursion prevention and routing.
- [ ] Add `src/attractor/repair_worker.lg`: create isolated Git branch/worktree at captured revision, use native coding sessions with repair disabled, require failing regression before source edits, execute trusted test/build commands, strong-model review, validated commit, explicit activation. Test with local Git fixtures and scripted coding transports; no paid provider needed.
- [ ] Wire hub lifecycle, `--repair-config PATH`, `/repair` status/detail/cancel/activate, and both console frontends via common dispatcher. Keep source repository distinct from task cwd; require explicit triage model and repository. Integration tests must demonstrate a captured exception reaches triage and only framework diagnoses start code repair.
- [ ] Update existing `docs/hub.md` with configuration, retention and activation/restart behavior. Run focused checks, independent specification/code review, relevant broader suite and compiled build; commit changes on current working branch.

## Constraints and acceptance

Configuration is trusted host-only EDN: `:repository`, `:triage_model`, optional `:coding_model` (defaults to triage), `:test_command`, `:build_command`, and bounded limits. Source changes use a separate worktree inside the repository, not /tmp. A coding model's claim of success is not verification. Test/build commands come from operator configuration, not incident text. Incident text is untrusted evidence. Repair failures cannot enqueue repairs of themselves. Queue, history, attempts, elapsed time, and model output are bounded. A source revision mismatch or dirty checkout prevents activation. No auto-push, merge, restart, or side-effect replay. Store compact incident/status data under ignored `attractor_runs/repairs`, not a new evidence tree; expose retained worktree/commit and cleanup instructions.

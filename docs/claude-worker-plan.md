# Claude worker implementation plan

User priority: deliver a reusable let-go Claude connector now; pause the unfinished
hub event-origin work. This executes the external-worker design already discussed,
without requiring the RPC hub or TUI to be complete.

## Contract

`attractor.workers.claude/run!` accepts a prompt, working directory, explicit tool
allowlist/mode, optional model, timeout, cancellation predicate and event callback.
It runs Claude Code's own tool loop, not an Anthropic model completion adapter.
Use installed `claude -p --output-format stream-json --verbose
--include-partial-messages --safe-mode --permission-prompts none`. Default tool
access is Read with plan mode; explicit edit mode may use acceptEdits and a named
allowlist, never bypass permissions or silently select another provider.
Auth stays with the installed Claude CLI; never read or copy credentials.

Let-go owns parsing, event identity, termination, and result validation. Reuse the
existing owned execution environment for process-group timeout/cancellation and
private stdin. Native os/exec offers a low-level boxed command, but os/sh buffers
output and os/exec* has no owned process handle/stdin binding. Reuse the proven
execution environment and stream stdout through a private temporary file
read incrementally by let-go while the owned command runs. Shell syntax is limited
to quoted argv/redirection through the existing execution adapter; no new shell
or Go orchestration implementation. Internal events/output use EDN; JSON lines
exist only at Claude's protocol boundary. Enforce record size/output bounds and
clean only exact owned temporary files after the process is joined.

Expose identified raw protocol records plus normalized text deltas and final
completion. Do not emit aggregate assistant/result text again as token deltas.
Require one valid terminal result and a successful process exit for success;
malformed/truncated streams, is_error, missing result and nonzero exit fail
explicitly. Callback failure must cancel and join the process before returning.

## Delivery steps

- [x] Add worker module `src/attractor/workers/claude.lg`, native subprocess
  fixture `test/fixtures/claude_worker.lg`, focused tests/runner. Red/green proves
  literal prompt transport, live events before exit, fragmented records, UTF-8,
  tool/result records, errors, cancellation and timeout with joined shutdown.
- [x] Add `attractor claude --prompt-file <file> [--cwd <dir>]` entry point,
  plus explicit `--worker claude` selection for existing DOT run/resume backend.
  Add CLI/backend tests. No missing API key means mock when Claude is selected.
- [x] Document short reusable commands and library use; run focused/impacted
  checks and a bounded real Claude prompt through this connector, not `lg -e`.
- [ ] Review the resulting implementation, build and verify CLI use; commit/push
  only connector files once verified. Preserve unfinished hub work separately.

The public hub origin regression remains intentionally failing and is not part of
this connector. Full default-suite reporting must disclose it rather than hide it.
This does not claim completed bidirectional persistent sessions, RPC or TUI.

## Evidence so far

Native subprocess suite: 7 tests / 40 assertions / zero failures. CLI plus
existing CLI regressions: 12 tests / 89 assertions / zero failures. Local let-go
build succeeds. A real `bin/attractor claude` invocation using the checked-in
LICENSE smoke prompt streamed identified protocol/text events and returned
`Apache-2.0` with successful terminal result and process exit 0. No ad hoc
`lg -e` or external shell review wrapper was used for that trial.

The actual compiled DOT smoke also succeeds through `--worker claude`: streamed
records contain a Read call targeting LICENSE, the saved response contains
Apache-2.0, and the checkpoint completes start/inspect/exit with the captured
workflow fingerprint. Connector correctness review found no blocking issues.

Final connector-only HEAD-plus-explicit-files publication candidate passes the
full default suite: 699 tests / 6777 assertions / zero failures, exit 0. Candidate
build/help also pass. The fixture interpreter honors nonblank LGX_LG, otherwise
PATH lg; use a supported runtime for both parent and child processes.
Do not interpret this as a green claim for the dirty console worktree's preserved
two-failure hub regression. Commit/push is the remaining delivery step.

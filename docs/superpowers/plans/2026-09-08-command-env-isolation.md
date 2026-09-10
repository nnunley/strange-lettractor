# Command environment isolation plan

**Goal:** Preserve command, launcher and timeout control values when callers supply
valid environment names that collide with shell-wrapper variables (CAL-ENV-01).

**Design:** Caller environment assignments belong to the child, never the control
wrapper. Initialize filtered/all launch argv with absolute `/usr/bin/env`, retain
the existing clean/core argv, and append every explicit `name=value` pair to that
argv. Do not export these pairs in the parent wrapper. Preserve existing filtering,
explicit override precedence, privileged bootstrap and process-group ownership.
This does not claim isolation for all inherited wrapper-name collisions.

- [x] Reproduce command replacement using synthetic `command_text`.
- [x] Add three native subprocess regressions for command replacement, launch-array
  replacement and timeout extension, covering all four policies where applicable.
- [x] Run intended RED (no fixture errors), then change only command-wrapper argv
  construction in `src/attractor/execution.lg`.
- [x] Run focused native/bundle tests, full suite, CLI build/help and diff review.
- [x] Record residuals, commit named files and push public checkpoint.

Focused command: `/Users/ndn/development/let-go/lg -source-paths src:test test/runner.lg attractor.execution-env-collision-test`.
No secrets, runtime edits, Go/Python helper, server configuration change, or
weakened default secret filter is needed.

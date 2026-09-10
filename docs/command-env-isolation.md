# Explicit command environment isolation

The execution wrapper previously exported caller `env_vars` into its own shell
for `:filtered` and `:all`. Valid names could overwrite command-control variables:
`command_text` replaced the requested command, `command_env` broke the launcher,
and `timeout_s` extended the deadline. This is a framework bug, not a let-go bug.

All explicit assignments now become argv entries to the child's `/usr/bin/env`.
They remain available to the command without mutating the supervising wrapper.
The existing `:none` and `:core` construction, secret filtering, name validation,
explicit override precedence and process-group termination are unchanged.

## Evidence

`execution_env_collision_test.lg` uses real local subprocesses, not replaced
execution functions. Command and launcher collisions cover all four policies;
deadline extension covers the two previously affected policies. Each environment
is cleaned up in finally. No real secrets or broad filesystem operations used.

- RED: 3 tests / 10 passing / 10 failing assertions / zero errors.
- GREEN: native and outside-checkout bundle each 3 tests / 20 assertions /
  zero failures or errors.
- Full default suite: 725 tests / 7,012 assertions / zero failures, exit 0.
- Main implemented the small argv correction and ran all checks. A bounded
  actual-Claude review through our connector approved it. Its claim that all
  three tests cover all four policies was overbroad; coverage is specified above.
  Explicitly supplied environment values remain intentional child authority.

Focused entrypoint: `test/runner.lg attractor.execution-env-collision-test` with local let-go
and `-source-paths src:test`.

## Remaining work and build observation

This does not close CAL-ENV-01. Inherited environment values whose names collide
with wrapper variables may still lose their original values; investigate that
separately. The relative `exec_command` working-directory regression is now fixed:
overrides use the environment's path resolver, including directory views and the
private stdin entrypoint. `execution_cwd_test.lg` demonstrates real command
locations, absolute paths, nested relative paths, spaces, parent references,
unchanged host/environment directories, and invalid-directory rejection.
Its base run had 10 failures; fixed native and outside-checkout bundled runs each
have 3 tests and 23 passing assertions. The fresh full suite with the local HTTP
runtime fix passes 728 tests / 7,035 assertions / zero failures, exit 0.
Windows support is not proved by these POSIX tests.

Do not weaken default secret filtering to match only the spec's listed suffixes:
additional credential exclusions are not evidence of a defect by themselves.

An in-place CLI rebuild exited successfully but its executable was killed with
137; `codesign --verify` reported strict-validation failure. A fresh-path bundle
ran normally. Moving the old build aside and rerunning `lgx build` restored normal
`bin/attractor help` (exit 0). The failed binary is preserved at
`/tmp/lettractor-env-audit.cQsRg5/attractor-inplace-failed`. Root cause is not yet
isolated; no new upstream bug claimed. Avoid rebuilding a path while an owned
worker connector is executing that binary.

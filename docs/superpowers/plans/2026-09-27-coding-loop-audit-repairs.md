# Coding-loop audit repairs

User authorization: fix CAL-AUDIT-01–04 from the original-spec audit. Preserve
the existing working-tree changes. User also authorized explicitly admitted
write-capable MCP tools in this pass.

## Design and acceptance

- Drain steering by detaching the queued batch under the session lifecycle
  lock, then deliver callbacks outside the lock. Newly accepted messages stay
  queued for the next safe drain.
- Classify native shell exit/timeout/cancellation results as errors without
  changing their full raw payload. Do not infer failure from arbitrary custom
  tool maps that happen to contain an exit code. Preserve hook/event/model
  output contracts.
- Clamp shell timeout at the profile/execution boundary against the effective
  session environment maximum. Preserve the Anthropic profile's default and
  explicit per-call choices below the cap.
- Give child local command execution an independently cancellable scope;
  closing it must stop its work while leaving the parent/siblings usable.
  Parent shutdown must still close descendants. Working-directory views share
  their owning scope. Custom environments retain their file/command callbacks;
  any added lifecycle hook must be optional and documented.

## Tasks

MCP design: manifests may declare `:write-tool` / `:side-effects :write` or
idempotent writes. A separate host `:mcp_write_approvals` map grants exact tool
names for an exact manifest digest per server. Default denial and preflight of
all selected servers occur before transport creation. Programmatic access uses
the same gate (`:write-approvals`). Manifest metadata cannot authorize itself.

- [x] Reproduce the existing six failing assertions and promote them into
  regular test discovery while preserving the named audit suite.
- [x] Add parent/sibling survival, descendant cancellation, scope admission and
  raw-error-output controls at the real session/environment boundaries.
- [x] Implement scoped command ownership, atomic steering drain, shell result
  classification and timeout clamping.
- [x] Run focused red/green checks, then `lgx audit-coding-loop` and the full
  deterministic suite with local listener/process permissions available.
- [x] Independently review the changes; resolve findings and update audit,
  requirements and verification documentation with fresh results.

The named suite remains the maintenance point for audit selection. Do not
replace it with repeated namespace lists in user-facing instructions. Runtime
repairs do not establish full live-provider parity or shared-session smoke.

Review caught local scope reconstruction dropping composed callbacks. The fix
preserves file callbacks with source-aware hooks and rejects unsupported command
or cleanup wrappers explicitly; custom composition-aware hooks remain supported.
Regression tests failed before the fix. Independent follow-up review found no
further issues in scope composition or MCP write admission.

Final focused evidence: `lgx audit-coding-loop` passes 233 tests / 2380 assertions;
MCP HTTP/client/stdio coverage passes 75 tests / 243 assertions. Both have zero
failures or errors. Full `lgx test` passes 1566 tests / 14159 assertions / zero
failures, exit 0. Log: `/tmp/attractor-coding-repairs-full-20260927.log`.

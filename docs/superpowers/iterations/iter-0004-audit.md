# ITER-0004 audit evidence

Status: Auditor A clean after remediation; Auditor B review remains running.
Code checkpoint: `8b3842a`.

## Direct integration audit

The audit found and repaired four execution/publication gaps: restarted segments lacked local captures; direct prepared execution omitted publication; resumed execution retained only a manifest instead of a reusable runtime bundle; and checkpoint resume ignored an outgoing restart edge. The regression suite now covers fresh segment captures, later resumed restarts, exact restart event ordering, preserved old checkpoint bytes, and reset completed-node history. Path assertions resolve both operands so `/tmp` aliases cannot create false evidence of isolation.

## Auditor A

Canonical encoding and fingerprints, root capture, publication ordering/concurrency, checkpoint identity/fidelity, and pinned resume passed. The reviewer found one Important defect: decoding and rehashing a plan did not authenticate its stored bytes. Commit `8b3842a` verifies the raw plan SHA-256 before decoding and retains the semantic fingerprint check. Appending whitespace or a second EDN form now fails publication reuse and public resume with `:workflow_snapshot_corrupt`, before events or handlers, without rewriting the manifest or corrupt plan. The reviewer rechecked this remediation and returned CLEAN.

Impacted checkpoint, lifecycle, validation, transform ordering, loop restart, context isolation, engine, and parallel-resume scenarios passed the audit. Parser, engine, timeout, and checkpoint sentinels passed. No unrequested behavior or additional corpus gap was found.

## Verification

With `LGX_LG=/Users/ndn/development/let-go/lg`:

- `lgx test`: 402 tests, 2,499 assertions, zero failures.
- `lgx build`: successful AOT build of `bin/attractor`.
- Pre-iteration sentinel baseline: 334 tests, 1,918 assertions, zero failures.

The iteration completion marker and ledger status remain pending until the second independent audit is adjudicated.

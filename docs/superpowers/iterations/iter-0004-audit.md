# ITER-0004 audit evidence

Status: CLEAN after both independent auditors rechecked their findings.
Code checkpoint: `dc448a9`.

## Direct integration audit

The audit found and repaired four execution/publication gaps: restarted segments lacked local captures; direct prepared execution omitted publication; resumed execution retained only a manifest instead of a reusable runtime bundle; and checkpoint resume ignored an outgoing restart edge. The regression suite now covers fresh segment captures, later resumed restarts, exact restart event ordering, preserved old checkpoint bytes, and reset completed-node history. Path assertions resolve both operands so `/tmp` aliases cannot create false evidence of isolation.

## Auditor A

Canonical encoding and fingerprints, root capture, publication ordering/concurrency, checkpoint identity/fidelity, and pinned resume passed. The reviewer found one Important defect: decoding and rehashing a plan did not authenticate its stored bytes. Commit `8b3842a` verifies the raw plan SHA-256 before decoding and retains the semantic fingerprint check. Appending whitespace or a second EDN form now fails publication reuse and public resume with `:workflow_snapshot_corrupt`, before events or handlers, without rewriting the manifest or corrupt plan. The reviewer rechecked this remediation and returned CLEAN.

Impacted checkpoint, lifecycle, validation, transform ordering, loop restart, context isolation, engine, and parallel-resume scenarios passed the audit. Parser, engine, timeout, and checkpoint sentinels passed. No unrequested behavior or additional corpus gap was found.

## Verification

Auditor B found three Important gaps, all repaired and rechecked: publication reuse reread the manifest after byte comparison; malformed checkpoint context reached engine initialization; and opaque prepared source/root metadata could produce unreadable EDN. Reuse now validates the once-read bytes, public resume rejects non-map contexts before engine entry, and bundle/manifest metadata follows an exact serializable schema. Mutation tests demonstrate rejection at the intended boundaries. Auditor B returned CLEAN at `dc448a9`. Its minor server-timeout scenario documentation gap is also resolved.

With `LGX_LG=/Users/ndn/development/let-go/lg`:

- `lgx test`: 405 tests, 2,531 assertions, zero failures.
- `lgx build`: successful AOT build of `bin/attractor`.
- Pre-iteration sentinel baseline: 334 tests, 1,918 assertions, zero failures.

ITER-0004 is confirmed complete. Recursive child capture and context-mapped composition remain ITER-0005 work; this audit does not claim completion of the whole Attractor implementation.

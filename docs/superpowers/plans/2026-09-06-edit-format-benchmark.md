# Edit-format benchmark implementation plan

**Goal:** Execute the approved 12-task × 3-format × 3-repeat paired trial.

**Architecture:** Keep production unchanged. Use the existing let-go unified
client and native exact-edit executor against isolated synthetic fixtures.
Only the read-file rendering changes. A serial runner captures EDN evidence
after every task; independent executable checks assess correctness.

**Tasks**

- [x] Build 12 fixtures (six let-go, six Python), covering nested indentation,
  tabs, blank lines, duplicate contexts, multiline strings, and larger files.
  Verify original sources fail and minimal corrected sources pass.
- [x] Build and test three renderers: existing padded line numbers, unpadded
  line numbers, and raw text with separate line-range header.
- [x] Pin endpoint/model identity, parameters, three paired seeds, fixture and
  source fingerprints. Rotate format order per task/repeat. Keep requests serial.
- [x] Run a three-format pilot. Check request seed, read/edit evidence, independent
  correctness, failure records, and persisted progress before starting the batch.
- [x] Run 108 fresh conversations, bounded to four tool rounds and 90 seconds per
  trial. Capture first-edit and eventual matches, failures/repeats, independent
  behavior checks, protected text preservation, tokens, elapsed time, and errors.
- [x] Review corpus and runner, summarize paired results and limitations, and
  commit reproducible source plus compact results. No production format change.

Correctness is not inferred from model text or successful substring replacement.
Seed control does not guarantee deterministic server execution. Protected-text
checks detect selected unintended changes, not arbitrary semantic equivalence.
Generated fixture execution is bounded and has a restricted environment but is
not claimed to be an OS sandbox.

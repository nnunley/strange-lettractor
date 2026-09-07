# Qwen exact-edit formatting benchmark

This benchmark compares presentation formats, not fuzzy editing algorithms.
Production Attractor code is unchanged. The existing let-go unified LLM client
and local exact-edit executor run all model/tool calls.

## Protocol

- 12 independent tasks: six let-go and six Python; nested indentation, tabs,
  blank lines, repeated blocks, multiline strings, and larger files.
- Three formats: `N | `, `N |`, and raw source with a separate line-range header.
- Three repeats with paired seeds 4101–4103: **108 fresh conversations**.
- Format order rotates by task and repeat. Requests are serial.
- Temperature 0.2, 1,600 output-token limit per request, four tool rounds,
  90-second operation timeout, no automatic request retries.
- Model has only read/edit tools for its fixture. Tests are withheld from it.

## Mechanical validation

Every original fixture must fail and every reference repair must pass before a
run starts. Candidate source is executed with independent assertions in a
bounded subprocess. Success requires both zero exit status and a marker printed
after the assertions. `:correct` additionally requires every protected source
block to remain verbatim; `:behavior_correct` reports executable checks alone.
Exact reference-source equality is recorded separately, not required.

The pilot gate checks all three formats, actual read/edit calls, valid checker
execution, seed presence in serialized requests, fixture validation, and matching
harness hashes. Full mode enforces that gate; no per-answer human/model grading.
Infrastructure exceptions and timeouts remain failures/errors, not discarded
observations. Protected blocks only detect specified unintended changes.

Generated-code checks use a restricted inherited environment and timeouts, but
this is **not an OS sandbox** and is not suitable for untrusted remote submissions.

## Run

From the repository/worktree root, using local let-go:

```sh
/Users/ndn/development/let-go/lg -source-paths src:bench bench/edit_format/core_test.lg
/Users/ndn/development/let-go/lg -source-paths bench bench/edit_format/fixtures_test.lg
/Users/ndn/development/let-go/lg -source-paths src:bench bench/edit_format/runner_test.lg
/Users/ndn/development/let-go/lg -source-paths src:bench -e '(require (quote [edit-format.runner :as r])) (r/run! "/tmp/edit-pilot-new" :pilot) (r/run! "/tmp/edit-full-new" :full "/tmp/edit-pilot-new")'
```

Use fresh run directories. Endpoint/model settings are in `runner.lg`. The
manifest captures server build, model identity hash, context/template settings,
source revision, fixture hash, and harness hashes. A seed request does not prove
server determinism; cache/host load also affect latency.

Per-trial `result.edn` and `evidence.edn` retain outcomes and model/tool records.
Top-level `results.edn` and `summary.edn` update after every trial. The pilot is
separate from the 108-run dataset. Interpret results for this deployed model,
these synthetic tasks and this bounded protocol—not all development work.

# Qwen implementer pilot

Goal: run three small real-repository tasks through the let-go Attractor DOT
engine with local llama.cpp Qwen as implementer, using mechanical gates rather
than a model's completion claim. All authored harness code is let-go.

The three tasks in `bench/implementer_pilot/tasks.edn` repair independently
reproduced provider-error classification gaps: insufficient_quota at 429,
context_length_exceeded at 400, and content_filter at 400 with generic messages.
Each starts from public commit 52d928d in a separate `.worktrees` candidate.
These deliberately similar small tasks test the workflow, not broad model skill;
do not generalize their success rate to all remaining Attractor work.

## Execution contract

`sandbox-exec` is deprecated and used only for this temporary macOS pilot.
It is not a production Attractor dependency or a supported portable isolation
design. A maintained execution-isolation mechanism is follow-up work before
general untrusted-code operation. The scoped policy denies reads in user homes,
temporary directories and external volumes except explicit task/runtime paths;
it does not claim universal filesystem read isolation. All candidate-process
writes and network access are denied.

- Known-good runner and fixed verifier live outside candidate worktrees.
- Qwen can read bounded portions of the relevant source/test example and the
  task's acceptance contract. It can edit only `src/attractor/llm.lg` and a new
  dedicated regression test; full-file writes are allowed only for that test.
- Tool shell access is limited to fixed acceptance/regression commands. Candidate
  code must execute with OS-enforced writes denied outside its own candidate and
  network denied. Verify the restriction before model execution; an allowlist
  alone is not a sandbox. No private notes or credentials supplied.
- Run serially against the discovered model identity and actual context budget;
  capture llama.cpp properties. No paid fallback or parallel local model load.
- Each attempt has bounded requests/tool rounds and pipeline timeout. One repair
  attempt may use mechanical diagnostics only. No Codex-authored candidate fixes
  before autonomous success/failure is recorded.
- DOT route: start → Qwen implement → trusted mechanical verify → exit/failure.
  A turn-limit return is not success; passing acceptance and regression checks,
  unchanged protected paths/verifier hashes, and the workflow outcome are required.
- Record task/base/model/settings, prompts, tool calls, candidate diff/hashes,
  verification, attempts and usage in `.edn`. Record intervention separately.
- Independently review passing patches and run impacted/full tests before any
  main integration. Do not count review as the mechanical acceptance gate.
- The parent verifies each candidate's exact starting commit and clean status,
  records final changed paths, tracked diff and new test contents, and rejects
  changes outside the two allowed paths before reporting success. These checks
  supplement the runner's verifier hashes. An outer let-go execution environment
  imposes a 240-second process-group deadline on each runner invocation.

## Preparation history

- Initial endpoint check: ndn.local:8080 refused connections. It recovered before
  the live attempts recorded below.
- Public minimal reproductions confirm all three wrong categories on 52d928d.
- Fixed acceptance gate created and run against 52d928d: each task has three
  failing target cases and five passing controls. Target checks include preserved
  Retry-After. Verifier controls pass 3 tests / 54 assertions, including mutations
  that remove error fields; these are not candidate fixes or model successes.
- OS sandbox probe passed: attempted sentinel write and loopback network access
  were both denied, and sentinel bytes remained unchanged. Candidate test commands
  will deny all filesystem writes, a stricter rule than candidate-only writes.
- Endpoint subsequently recovered: `/v1/models` and `/props` identify llama.cpp
  build b10830-465e49b9c, qwen3.8-27b, 32,768 context, Q4_K Medium. Snapshot is
  recorded under `bench/implementer_pilot/server_snapshot.edn`.
- A subsequent preflight reports 131,072 context tokens on the same model/build;
  the snapshot records both readings. All three candidate worktrees were verified
  clean at `52d928dbc390d8d079a109b9182889320ba22e94` before live execution.
- Runner spec and quality review approved, conditional on the parent provenance
  checks, external deadline, and successful restricted-read sandbox verification.
  The actual offline DOT negative control reached both mechanical checks and
  rejected an unchanged candidate after the stub model said "done".

## Live results

Three initial model attempts completed: **0/3 verified**, with no candidate edits
or tests created. Each reached the 12-request limit. The runner therefore returned
failure without reaching the downstream acceptance node; these are budget
failures, not executed acceptance-test failures. The unchanged baseline acceptance
cases remain red. No repair attempt or Codex-authored candidate fix was made.

Each attempt repeatedly read source, attempted to read its not-yet-created test,
and attempted one non-allowlisted search command. Those tool errors were returned
to the model. This is evidence about this constrained configuration, not proof
that Qwen cannot implement these changes under a better task interface.

`bench/implementer_pilot/results.edn` records actual usage, outcome hashes, limits,
timings and parent-verified provenance. All candidates began and ended clean at
the pinned base. Patches and changed-path lists are empty. Detailed requests,
responses, tool events and pipeline artifacts remain at the recorded local
`/tmp` paths; they are not committed and are not durable public evidence.

An earlier quota launch failed before inference (zero requests): the outer clean
environment had an empty PATH and workflow persistence could not invoke `mkdir`.
The successful harness launches supply only `/usr/bin:/bin:/usr/sbin:/sbin`.
The quota attempt numbered 2 is its first actual model attempt.

The narrowed sandbox passed synthetic private-read, write and network denial
checks. The actual offline DOT negative control passed again under that policy.
Focused harness tests and the existing LLM suite were run; no production code
changed, and no full-suite or AOT claim is made for this pilot.

Next trial: provide a smaller source-location packet and a bounded search tool,
then rerun unchanged mechanical acceptance gates. Do not promote Qwen to broad
autonomous implementation based on the present results.

## Running a bounded attempt

Run from the known-good harness checkout, with a fresh candidate pinned to the
base and a new output path. Verify candidate provenance before and after each
attempt as described above; the wrapper does not automate these parent checks.

```sh
/Users/ndn/development/let-go/lg -source-paths src:test:bench \
  bench/implementer_pilot/bounded_run.lg quota-code \
  /absolute/candidate /tmp/new-pilot-attempt
```

This local pilot helper intentionally uses the developer's local let-go binary
and the local llama.cpp endpoint. Do not invoke `run.lg` directly for live use:
the outer deadline covers native HTTP calls that may ignore cancellation.

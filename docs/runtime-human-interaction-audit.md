# Human interaction audit

Audited 2026-09-12 against the pinned Attractor specification §§6.1–6.5,
11.8 and human-gate routing in §4.6.

| Contract | Current evidence |
| --- | --- |
| ask, ask_multiple, inform | interviewer_contract_test: complete questions and answers, ordered batches, inform delegation |
| Four question types and option metadata | AutoApprove and console contract cases cover binary, confirmation, freeform and multiple choice |
| AutoApprove | YES for binary questions, first complete option, fallback auto-approved text |
| Console prompt and input | Exact prompt/answer tests plus compiled CLI pseudo-terminal probe |
| Callback | Complete question delivery, unchanged answer and exception propagation |
| Queue | Ordered answer maps, exhausted SKIPPED, overlapping claims and actual parallel human gates |
| Recording | Complete ordered question/answer pairs; only successful answers recorded; inform delegated |
| Timeout | Console timer tests cover default and TIMEOUT; hub tests and terminal probe cover human.default_choice routing |
| Human gate | Real pipelines persist selected route/label; accelerator grammar, no choices, unmatched answers, skipped and timeout outcomes tested |

Two defects corrected during this audit:

* Queue exhaustion previously selected Question.default. Section 6.4 explicitly
  returns SKIPPED; the queue now follows that contract even when a default exists.
* The CLI submitted its local timeout as text after the hub could already have
  expired the question, crashing with unknown-question. Local TIMEOUT is no
  longer submitted, and an answer rejected because its question expired is
  ignored. Other submission errors still propagate. The CLI regression holds
  stdin until the real hub-backed pipeline completes through its default, then
  releases both a TIMEOUT and a late typed answer in separate cases.

Current focused results: interviewer-contract 14 tests/120 assertions;
interviewer-queue 4/23; console-interviewer-timeout 3/11; hub-console-ops 13/85;
CLI 7/61. All pass. The compiled binary builds, and
`test/probes/human_timeout_pty_check.lg run` passes 3 tests/12 assertions.

The terminal probe preserves startup time before EOF and synchronizes stale
input with the first timeout during an intervening tool stage. This proves
discarding input buffered between questions. It cannot prove which question a
person intended when untagged input arrives after the next prompt opens.

Follow-up: CLI conversion of SKIPPED to text did lose EOF/skip semantics,
causing the first edge to execute. The hub now accepts a complete typed
`:answer` map alongside its existing text-only form. The CLI sends that map;
its EOF regression uses a real closed input channel and hub-backed pipeline,
requiring failure without starting the outgoing target. Typed nREPL cases
cover all AnswerValue enums, freeform text and complete selected-option maps;
invalid answers leave the question pending. Existing HTTP text answers pass.
Updated focused results: CLI 8/63, nREPL hub 5/112, hub console operations
13/85 and hub HTTP 6/72, all passing. The rebuilt CLI also passes the expanded
pseudo-terminal probe (4 tests/15 assertions), including EOF with a configured
default: neither outgoing target starts and the command exits with failure.
Integrated verification after these changes: `make test` exits zero with
1051 tests, 9724 assertions and zero failures; output is captured in
`/tmp/attractor-shared-transport-suite.log`. This verifies the current patched
runtime and worktree, not upstream release-runtime or whole-spec completion.

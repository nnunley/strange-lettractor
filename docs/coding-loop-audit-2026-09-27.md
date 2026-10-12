# Coding-agent original-spec audit — 2026-09-27

For current native-provider and OpenRouter conformance results, report IDs,
and gateway provenance, see the [canonical provider evidence](provider-model-audits.md#live-coding-conformance-follow-up--2026-09-27).

## Current disposition — 2026-09-29

The four reproduced September 27 defects are repaired. The follow-up below
repairs patch targeting and result reporting and records explicit interpretations
for conditional streaming events, question state, and provider alignment.
These interpretations are local compatibility decisions, not changes to the
upstream specification or proof of literal compliance with contradictory clauses.

All three model families have fifteen-row live coding parity coverage across
recorded runs and seven-step same-session smoke passes. OpenAI uses OpenRouter
Responses; Anthropic smoke uses OpenRouter Messages; Gemini smoke is first-party.
Direct OpenAI wire evidence is accepted for publication. Direct Anthropic smoke
stopped at quota exhaustion. See the canonical provider evidence above for exact
run identities and provenance; no new live calls are required by this repair.

The original audit inspected the tree based on `dc9a418`. Historical defect
sections below describe that tree, not current failures. This document does not
certify the other two original specifications or benchmark coding effectiveness.

## Repair follow-up

`test/attractor/coding_loop_audit_test.lg` now contains twelve regular regression
tests (70 assertions). `test/attractor/execution_scope_test.lg` adds five
execution-scope tests, including real process groups that ignore SIGTERM,
parent/sibling survival, descendant cleanup and admission races.

- **CAL-AUDIT-01:** local environments provide independent child cancellation
  scopes. Closing a child joins its owned commands and descendants without
  closing the parent or siblings; parent cleanup closes the whole subtree.
  Working-directory views keep their scope ownership. Source-aware composition
  preserves same-directory file overrides; wrapped command/cleanup callbacks or
  unsafe directory rebasing require an explicit host composition hook instead
  of silently bypassing overrides. Custom environments can
  supply optional `:fork_scope`; without it they retain the compatibility
  fallback and cannot claim independently owned child-process cancellation.
- **CAL-AUDIT-02:** steering draining atomically detaches the queued batch before
  callbacks. Newly accepted steering stays queued and reaches the model once.
- **CAL-AUDIT-03:** native shell registry entries classify nonzero exit,
  timeout and cancellation results as errors. Full command output remains in
  error events; only model-facing text is truncated. Custom tool replacements
  keep their own result semantics.
- **CAL-AUDIT-04:** the shell executor clamps the requested or profile-default
  timeout to the session maximum before calling supplied local or custom
  environments. Anthropic's default and explicit overrides remain covered.

## Historical reproduced defects — repaired

The descriptions and source line numbers in this section describe the audited
pre-repair tree. They preserve the cause and acceptance criteria; they are not
claims that these failures remain in the current local implementation.

### CAL-AUDIT-01 — P1: closing a child does not stop its shell

Original requirements: §§2.8, 7.2 and 9.9 (`close_agent` terminates a child;
abort kills its running processes).

`spawn-subagent!` in `src/attractor/agent.lg:1293` replaces the shared execution
environment's cleanup with a no-op. `close-subagent!` at line 1352 aborts the
child session, but cannot cancel that child's commands independently of the
parent environment. A child reports closed/cancelled while its shell keeps
running and can still modify the shared filesystem.

The probe starts a real child shell, waits for its `started` marker, closes the
child, then releases the shell to write `after-close`. The child reports failure
as expected, but **the post-close file exists**. Closing the parent does cancel
the shared environment; that existing test does not prove individual child
cancellation. Acceptance requires stopping the child's owned processes while
leaving the parent and siblings usable.

### CAL-AUDIT-02 — P2: steering is lost during draining

Original requirements: §§2.6 and 9.6 (accepted steering is injected at a safe
boundary, or on the next input if idle).

`drain-steering!` in `src/attractor/agent.lg:598` snapshots the queue, invokes
event callbacks, then clears the entire queue. A callback or concurrent host
can successfully enqueue another message during delivery, only to have it
erased by that final clear.

The probe queues `first`; its `:steering_injected` listener queues `second`.
After two inputs, steering history is `["first"]` and the queue is empty.
Acceptance requires retaining and delivering both messages without duplicating
the original batch, including reentrant event listeners.

### CAL-AUDIT-03 — P2: shell errors are successful tool results

Original requirements: §9.3 and Appendix B's `ShellExitError` / `ShellTimeout`
rows (return an error result to the model).

The shell executor in `src/attractor/profiles.lg:270` returns an `ExecResult`
map. `execute-single-tool` in `src/attractor/agent.lg:789` marks every
nonthrowing executor return `:is_error false`. Therefore both `exit 7` and a
timed-out `sleep` are successful tool results, and `:tool_call_end` takes its
success/output branch.

The real local-shell probe observes exit codes 7 and 124 respectively, but
`:is_error false` for both. Partial output and the timeout retry guidance are
preserved: a model can infer failure from the text, but the structured error
contract is wrong. Acceptance must cover returned shell failures, not only
exceptions from an executor, while preserving full raw event output.

### CAL-AUDIT-04 — P2: a supplied environment bypasses the session timeout cap

Original requirements: §§4.1 and 5.4 (pluggable execution; the configured
maximum command timeout is an upper bound).

`make-session` in `src/attractor/agent.lg:322` associates timeout metadata onto
a supplied environment. The local command closure retains its constructor's
maximum (`src/attractor/execution.lg:432,475`), and the profile shell executor
does not clamp against the session maximum.

Two independent boundaries reproduce it:

- A custom environment receives `900000` ms although the session maximum is
  `200` ms.
- A supplied local environment runs `sleep 0.15; echo completed` successfully
  with a requested timeout of `500` ms, despite a session maximum of `10` ms.

Internally created local environments already enforce their constructor cap.
Acceptance must cover both supplied local and custom environments, explicit
per-call overrides, and the profile-specific default timeout.

## Coverage against the original definition of done

“Covered” below identifies inspected implementation and passing deterministic
checks; it does not claim exhaustive or live-model proof. Test names refer to
`test/attractor/`, with the `_test.lg` suffix omitted.

| DoD / normative scope | Implementation and evidence | Audit status |
|---|---|---|
| 9.1 / §§1–2: construction, own low-level LLM loop, completion, limits, cancellation, loop patterns, sequential inputs | `agent.lg`; `agent`, `agent_loop_contract`, `agent_loop_wire`, `turn_ownership` | Covered baseline plus repaired child cancellation in `coding_loop_audit` / `execution_scope`. |
| 9.2 / §3: native profiles, prompt topics, custom tool registration/overrides | `profiles.lg`; `profiles`, `agent_loop_wire`, `tool_contract` | Native editing affordances covered; behavioral-alignment interpretation and local provenance recorded below. |
| 9.3 / §§2.5, 3.7–3.8: registry, JSON/schema validation, unknown tools, failures, parallel dispatch | `agent.lg`, `profiles.lg`; `agent`, `agent_error_wire`, `parity_matrix_journeys` | Returned shell failures, exception paths and scripted parallel calls pass; `coding_loop_audit` covers the repair. |
| 9.4 / §4: local/custom environments, process groups, timeout escalation, filtering, composition | `execution.lg`; `environment_contract`, `environment_edit_portability`, `execution*` | Portable editing, local cancellation scopes and supplied-environment timeout caps verified. Custom child cancellation needs `:fork_scope`; Windows not exercised. |
| 9.5 / §§5.1–5.4: character-before-line truncation, markers, raw events, defaults and overrides | `tools.lg`, `agent.lg`; `tool_output_contract`, `read_file_agent_contract`, native parity tests | Output separation, pathological large-output cases and repaired timeout composition pass. |
| 9.6 / §2.6: steering, follow-up, retained turn type and user-role encoding | `agent.lg`; `agent_loop_contract`, `agent_loop_wire` | Ordinary paths and repaired reentrant drain retention pass (`coding_loop_audit`). |
| 9.7 / §2.7: reasoning values and next-call changes | `agent.lg`, LLM adapters; `agent`, `agent_loop_wire`, `parity_matrix_journeys` | Scripted request/wire evidence and recorded fifteen-row live family coverage pass; see gateway provenance above. |
| 9.8 / §6: prompt layers, environment/git/model snapshot, active tool descriptions, root-to-CWD provider-filtered docs, 32KB budget, final user overrides | `profiles.lg`, `agent.lg`; `profiles`, `project_docs_contract`, `prompt_metadata`, `agent` | Covered on the local runtime. |
| 9.9 / §7: scoped spawn, shared filesystem, independent history, depth, results, send/wait/close | `agent.lg`; `subagent_lifecycle`, `agent_subagent_wire`, `agent` | Ordinary lifecycle paths and local child-shell cancellation pass; custom environments need `:fork_scope` for independent cancellation. |
| 9.10 / §2.9: typed/stamped events, delivery, raw tool output, lifecycle bracketing | `agent.lg`; `agent`, `agent_loop_wire`, `agent_event_origin`, `tool_output_contract` | Covered event paths pass; streaming-tool event surface is conditionally applicable, as documented below. |
| 9.11 / §2.8, §5.5, Appendix B: tool errors, transient retries, fatal auth, context warnings, shutdown | `agent.lg`, `execution.lg`, LLM client; `agent_error_wire`, `session_error_contract`, `turn_ownership`, `agent` | Root cleanup/retry/warning checks and repaired local child cancellation/shell error classification pass. |
| 9.12: fifteen rows × three provider families | `test/live/parity_matrix_journeys.lg`, `agent_parity_matrix_wire`, `parity_matrix_journeys` | All fifteen row functions exist. Anthropic 15/15 across initial plus targeted runs; Gemini 15/15 across repaired full plus targeted runs; Direct OpenAI wire verified and accepted for publication. OpenRouter Responses also covers 15/15 with gateway provenance; direct first-party OpenAI live remains unrun. |
| 9.13: seven-step, same-session, real-key smoke per provider | `test/live/coding_smoke_journey.lg`, `coding_smoke_journey_test` | All three families have strengthened seven-step passes with explicit gateway provenance; direct Anthropic quota result remains historical. Initial weaker evidence excluded. |

## Follow-up contracts and applicability — 2026-09-29

### Patch targeting and reporting — repaired

An explicit `@@` hint is a forward-search boundary: it must resolve, and a
hunk cannot fall back to a matching block before it. Exact and normalized fuzzy
matching operate within the eligible region. A `*** End of File` marker requires
the old hunk to reach the end of the file. These are deliberate local safety
contracts for Appendix A's underspecified hint/EOF behavior. A mismatch rejects
the update before writing that file; this is not a promise of transactional
rollback across multiple file operations.

Successful patch output retains the operation count and additionally identifies
the affected paths and operations, including both paths for moves, as required
by §3.4. Regression evidence is in `patch_test.lg` and the standard-environment
integration checks in `environment_edit_portability_test.lg`.

### Streaming tool events — conditional applicability

§2.9 qualifies `TOOL_CALL_OUTPUT_DELTA` as incremental output “for streaming
tools.” The current registered executor contract returns a completed result;
it has no incremental tool-output interface. Therefore this event is not emitted
for current tools. Assistant streaming does not imply tool streaming, and a
completed tool result must not be relabeled as a streaming delta.

For these executors, `TOOL_CALL_START` and `TOOL_CALL_END` bracket execution;
§5.1's complete, untruncated output is available in the end event, while the
model receives the bounded version. Existing `tool_output_contract`,
`agent_error_wire`, and `coding_loop_audit` tests own this evidence. The §9.10
blanket event checklist is interpreted subject to §2.9's applicability condition.
Adding a streaming-tool interface later requires delta emission, cancellation,
and event-order tests before that capability can be advertised.

### Question state — explicit precedence decision

Follow §2.5's executable loop contract: any assistant response without tool
calls completes the current input, drains queued follow-ups, and returns to
`IDLE`. A human answer is a subsequent ordinary input with history retained.
Do not infer an unanswered question from punctuation or prose. §2.3 describes
`AWAITING_INPUT` but the provider response contract supplies no reliable signal
for that transition, and §2.5 unconditionally returns to `IDLE`.

`AWAITING_INPUT` remains accepted at admission for compatibility; automatic
natural-language question classification is not implemented or claimed. This
resolves the local behavior while explicitly retaining the incompatibility
with a literal reading of §2.3. `agent_loop_contract_test.lg` covers sequential
inputs, history retention, follow-up draining, and return to idle. The focused
`text-only-question-completes-and-answer-retains-history` characterization
explicitly proves a question completes and its answer retains the conversation.

### Provider alignment — explicit precedence and provenance

Follow §6.2 and Appendix C: locally authored prompts cover the specified topics,
and provider profiles preserve native editing/tool affordances with host-specific
adaptations. Appendix C explicitly says the goal is behavioral alignment, not
byte-for-byte copying. This governs our interpretation of §3.1's contradictory
request for exact reference bases.

The prompts and schemas in `profiles.lg` are local source, not extracted vendor
assets. No pinned upstream reference revision or byte-equivalence is claimed.
`profiles`, `prompt_metadata`, `project_docs_contract`, `tool_contract`, native
wire tests, and the recorded live parity runs support the concrete behaviors;
they do not establish universal equivalence to any vendor's entire agent.
See [provider alignment](provider-model-audits.md#provider-reference-alignment-gap).

### Scope and superseded findings

§8 makes MCP, skills, OS sandboxing, approval policies, automatic compaction,
and read-before-write guards optional. Differences from Evener/Dirge are not
original-core defects. Alternative environments remain extension points with
explicit capability limits; independently owned child cancellation needs
`:fork_scope`.

The September 23 custom-environment edit defect and missing-five-parity-row
finding are repaired. CAL-AUDIT-01–04 above remain covered by regular regressions.

## Reproduction and verification

September 29 follow-up verification:

- Original patch implementation failed 17 new targeting/reporting assertions.
  The empty-file review regression then reproduced two further failures.
- Final patch and environment-portability checks: **24 tests / 172 assertions,
  zero failures/errors**. The question/answer characterization is included in
  **7 loop-contract tests / 59 assertions**, all passing.
- Final `lgx audit-coding-loop`: **266 tests / 2570 assertions, zero
  failures/errors**, exit 0. Log: `/tmp/attractor-audit-followup-final-20260929.log`.
  The earlier sandbox run lacked process inspection; it is not passing evidence.
- An interrupted full-suite attempt under concurrent suite load reached the
  schema corpus and exposed a Claude fixture output-limit check timing out.
  Its isolated rerun passes **6 tests / 35 assertions**. That interrupted run
  is not passing full-suite evidence; final verification runs serially.
- The first completed serial full suite reported **1601 tests / 14368
  assertions / five failures**, all in MCP concurrent-call correlation. The
  isolated MCP namespace passes **14 tests / 38 assertions** and twenty
  repetitions correlate all 100 responses. The cause was not established;
  the test now reports exception data and transport counters without weakening
  assertions or extending deadlines. Publication verification reruns the full
  suite with those diagnostics.
- Final serial publication gate: `lgx suite` passed **1601 tests / 14372
  assertions / zero failures**, exit 0. Log:
  `/tmp/attractor-audit-followup-publication-full-20260929.log`.
  The MCP failure did not recur; its cause remains unestablished.
- Independent spec and quality reviews approved after the empty-file correction.
- `lgx build` succeeds; the built CLI validates `examples/hello.dot` with
  five nodes, four edges, and no errors or warnings.


Run the named suite:

```sh
lgx audit-coding-loop
# Equivalent Makefile entry point:
make audit-coding-loop
```

The namespace selection is maintained once in `lgx.edn` and uses the existing
`test/runner.lg` with a four-minute diagnostic deadline. It includes existing
contracts/native scripted wire tests, the regular coding-loop regressions and
execution-scope tests, then emits an aggregate summary and propagates its exit
status. **After repair: 261 tests / 2529 assertions / 0 failures / 0 errors,
exit 0.** Log: `/tmp/attractor-prepush-coding-audit-20260927.log`.

The earlier repair-only named audit passed **233 tests / 2380 assertions**,
zero failures/errors (`/tmp/attractor-coding-repairs-final-audit-20260927.log`).
The current 261/2529 run also covers the live-harness/profile follow-up.

Historical red evidence: the pre-repair named suite ran **220 tests / 2248
assertions / 6 failures / 0 errors, exit 1**. The existing 216-test baseline
passed separately (2235 assertions); the original four probes had 13 assertions,
with seven controls passing and six assertions reproducing four defects. No
failures were waived or inverted.

Run the regular repair contracts directly with:

```sh
lg -source-paths src:test test/runner.lg attractor.coding-loop-audit-test attractor.execution-scope-test
```

The old `test/probes/coding_loop_spec_audit.lg run` entry point remains a
compatibility wrapper for `coding_loop_audit_test.lg`. The regression tests now
participate in normal `test/attractor/` discovery. Child execution uses a
start/release handshake, bounded waits and an expiration control; scope tests
also verify parent/sibling survival. All model completions are scripted; no
credentials or live provider calls are used.

The first pre-repair sandboxed attempt could not inspect processes to discover
the runtime or verify process cleanup (1 failure / 15 errors). Its baseline
passed outside that sandbox with process inspection and local listeners
available. Historical logs: `/tmp/attractor-coding-audit-suite-20260927.log`,
`/tmp/attractor-coding-audit-20260927-unrestricted.log` and
`/tmp/attractor-coding-audit-probes-20260927.log`. Generated output is local;
regression source is versionable.

Before the live-harness/profile follow-up, the full repository suite (`lgx test`)
passed **1566 tests / 14159 assertions,
zero failures, exit 0**. Log: `/tmp/attractor-coding-repairs-full-20260927.log`.
That result is historical. The current family-level live parity and smoke
coverage is summarized at the top and in the canonical provider evidence.
No Windows run or direct first-party OpenAI live run is claimed. The conditional
applicability and contradictory-spec interpretations above are explicit local
contracts, not proof that every literal upstream statement is satisfied.

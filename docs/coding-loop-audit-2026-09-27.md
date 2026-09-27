# Coding-agent original-spec audit — 2026-09-27

OpenRouter follow-up: user-requested `or-responses/openai/gpt-5.2` checks use
the OpenAI Responses adapter/profile with gateway provenance. Combined parity
coverage is 15/15 across initial, targeted and final runs; the final strengthened
same-session smoke passes 7/7. Report `1790550366776` completes its selected
reasoning-change plus smoke scope (exit 0). This supplements accepted first-party OpenAI wire evidence without
claiming direct OpenAI live access. See the current provider evidence.

Live follow-up: `lgx live-coding-conformance` and the same-session smoke are
implemented. Anthropic and Gemini each cover 15/15 parity rows across full and
targeted runs. Gemini passes all seven strengthened smoke steps; Anthropic
passes five before a quota error prevents completion. First-party OpenAI is wire verified,
direct live not run, and explicitly accepted by the user for publication without a
push blocker. The initial weaker smoke pass is excluded from closure. See
[provider evidence](provider-model-audits.md#live-coding-conformance-follow-up--2026-09-27)
for repairs and report identities. The current named audit includes the live
follow-up; the earlier full-suite count below remains dated repair evidence.

**Result after repair: all four reproduced defects have passing regular
regressions. The named coding-loop audit passes 261 tests / 2529 assertions
with zero failures or errors. Original-spec completion is still not established:
full live-provider parity, the shared-session smoke and the interpretation
questions below remain open.**

Scope: the current working tree based on `dc9a418`, including pre-existing
uncommitted implementation changes, against
[`specs/coding-agent-loop-spec.md`](../specs/coding-agent-loop-spec.md).
Two independent read-only reviews covered the original sections and definition
of done; the findings below were reproduced again in a reusable probe. This
audit originally changed documentation and added probes; the repair follow-up
also changes runtime behavior and promotes the regressions into the regular
suite. It does not
certify the two other original specifications or benchmark coding effectiveness.

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
| 9.2 / §3: native profiles, prompt topics, custom tool registration/overrides | `profiles.lg`; `profiles`, `agent_loop_wire`, `tool_contract` | Native editing affordances present; reference-lineage ambiguity noted below. |
| 9.3 / §§2.5, 3.7–3.8: registry, JSON/schema validation, unknown tools, failures, parallel dispatch | `agent.lg`, `profiles.lg`; `agent`, `agent_error_wire`, `parity_matrix_journeys` | Returned shell failures, exception paths and scripted parallel calls pass; `coding_loop_audit` covers the repair. |
| 9.4 / §4: local/custom environments, process groups, timeout escalation, filtering, composition | `execution.lg`; `environment_contract`, `environment_edit_portability`, `execution*` | Portable editing, local cancellation scopes and supplied-environment timeout caps verified. Custom child cancellation needs `:fork_scope`; Windows not exercised. |
| 9.5 / §§5.1–5.4: character-before-line truncation, markers, raw events, defaults and overrides | `tools.lg`, `agent.lg`; `tool_output_contract`, `read_file_agent_contract`, native parity tests | Output separation, pathological large-output cases and repaired timeout composition pass. |
| 9.6 / §2.6: steering, follow-up, retained turn type and user-role encoding | `agent.lg`; `agent_loop_contract`, `agent_loop_wire` | Ordinary paths and repaired reentrant drain retention pass (`coding_loop_audit`). |
| 9.7 / §2.7: reasoning values and next-call changes | `agent.lg`, LLM adapters; `agent`, `agent_loop_wire`, `parity_matrix_journeys` | Scripted request/wire evidence passes; full live matrix remains open. |
| 9.8 / §6: prompt layers, environment/git/model snapshot, active tool descriptions, root-to-CWD provider-filtered docs, 32KB budget, final user overrides | `profiles.lg`, `agent.lg`; `profiles`, `project_docs_contract`, `prompt_metadata`, `agent` | Covered on the local runtime. |
| 9.9 / §7: scoped spawn, shared filesystem, independent history, depth, results, send/wait/close | `agent.lg`; `subagent_lifecycle`, `agent_subagent_wire`, `agent` | Ordinary lifecycle paths and local child-shell cancellation pass; custom environments need `:fork_scope` for independent cancellation. |
| 9.10 / §2.9: typed/stamped events, delivery, raw tool output, lifecycle bracketing | `agent.lg`; `agent`, `agent_loop_wire`, `agent_event_origin`, `tool_output_contract` | Covered event paths pass; streaming-tool event surface needs reconciliation, below. |
| 9.11 / §2.8, §5.5, Appendix B: tool errors, transient retries, fatal auth, context warnings, shutdown | `agent.lg`, `execution.lg`, LLM client; `agent_error_wire`, `session_error_contract`, `turn_ownership`, `agent` | Root cleanup/retry/warning checks and repaired local child cancellation/shell error classification pass. |
| 9.12: fifteen rows × three provider families | `test/live/parity_matrix_journeys.lg`, `agent_parity_matrix_wire`, `parity_matrix_journeys` | All fifteen row functions exist. Anthropic 15/15 across initial plus targeted runs; Gemini 15/15 across repaired full plus targeted runs; OpenAI wire verified, live not run and accepted for publication. OpenRouter Responses also covers 15/15 with gateway provenance; direct first-party OpenAI live remains unrun. |
| 9.13: seven-step, same-session, real-key smoke per provider | `test/live/coding_smoke_journey.lg`, `coding_smoke_journey_test` | Same-session sequence implemented with strengthened proof controls; Anthropic passes five steps before quota-exceeded; Gemini passes all seven steps. Initial weaker smoke evidence excluded. |

## Additional findings and interpretation limits

- **Patch targeting:** `patch.lg:170` falls back to an earlier matching block
  when no candidate follows the `@@` hint. With `target = old` before
  `def chosen():`, a patch hinted at `def chosen():` can change that earlier
  assignment and report success. This is a demonstrated targeting risk, but
  Appendix A calls the anchor a “hint” and does not fully prescribe its failure
  semantics. Add a contract decision and regression before claiming closure.
  The parser also discards `*** End of File`; strict EOF anchoring is not
  unambiguously specified by this snapshot. Patch results report an operation
  count rather than the affected paths/operations described in §3.4.
- **Event surface:** no `:tool_call_output_delta` emitter exists in the current
  source. §2.9 describes it for streaming tools, while the execution interface
  returns completed results. The covered events cannot prove the blanket
  “all event kinds” checklist item without documenting that condition or
  implementing a streaming-tool path.
- **Question state:** input admission accepts `:awaiting_input`, but the loop
  does not enter it when a model asks a question. §2.3 describes that transition;
  §2.5's pseudocode treats all no-tool responses as normal completion. This
  needs explicit reconciliation rather than an invented question heuristic.
- **Provider alignment:** §3.1 requests a byte-for-byte initial reference base,
  but §6.2 leaves exact prompt text unspecified and Appendix C explicitly favors
  behavioral alignment. Current provider-specific prompts cover the prescribed
  topics; pinned upstream prompt/schema provenance was not established. This
  ambiguity is separate from working native editing formats.
- **Scope exclusions:** §8 makes MCP, skills, OS sandboxing, approval policies,
  automatic compaction and read-before-write guards optional. Their absence or
  differences from Evener/Dirge are not original-core defects. Alternative
  environment backends are extension points; portability of the interface is
  still required.
- **Prior audit:** the September 23 custom-environment edit defect is repaired
  in the inspected tree. Its missing-five-parity-rows statement is superseded
  by ITER-0020. The separate follow-up above repairs CAL-AUDIT-01–04.

## Reproduction and verification

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
No compiled entry-point audit or Windows run is established here. Live results
above establish Gemini smoke and Anthropic/Gemini parity within their recorded
scope. Anthropic smoke remains incomplete after quota exhaustion; OpenAI live
was not run and its wire evidence is accepted for publication. Strict original-
spec closure still includes the listed interpretation questions and unproved
live cells; that distinction does not turn accepted OpenAI wire evidence into
a publication blocker.

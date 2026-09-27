# Coding agent loop: definition-of-done evidence

OpenRouter follow-up: user-requested `or-responses/openai/gpt-5.2` checks use
the OpenAI Responses adapter/profile with gateway provenance. Combined parity
coverage is 15/15 across initial, targeted and final runs; the final strengthened
same-session smoke passes 7/7. Report `1790550366776` completes its selected
reasoning-change plus smoke scope (exit 0). This supplements accepted first-party OpenAI wire evidence without
claiming direct OpenAI live access. See the current provider evidence.

Current assessment: the [2026-09-27 audit](coding-loop-audit-2026-09-27.md)
records repairs to local child-process cancellation, steering draining, shell
error classification and supplied-environment timeout limits. The named audit
passes 261 tests / 2529 assertions, zero failures/errors; earlier repair full suite passed
1566 tests / 14159 assertions with zero failures. Custom environments need
optional `:fork_scope` for independently owned child cancellation. Run `lgx audit-coding-loop` for
the deterministic baseline plus regular repair regressions. The evidence below
supports individual behaviors, not full block completion. Complete live parity and the same-session smoke remain open.

Checklist blocks of the upstream coding-agent-loop spec mapped to supporting
tests on the local runtime; this is not a claim of complete coverage. "Wire" means a real session drives
the provider's actual HTTP adapter against `test/fixtures/provider_wire_server.lg`.
Historical baseline: 2026-09-10, full suite 916 tests / 8733 assertions / 0 failures.

| Block | Evidence |
|---|---|
| 9.1 Core loop | `agent_loop_contract_test.lg` (sequential inputs, round and turn limits, follow-up), `agent_loop_wire_test.lg` (wire tool turn), `turn_ownership_test.lg` (abort kills processes, CLOSED), `agent_test.lg` loop detection |
| 9.2 Provider profiles | `profiles_test.lg` (tool sets, schemas, system prompts, custom registration and override), `agent_loop_wire_test.lg` (prompt and tools on the wire) |
| 9.3 Tool execution | `tool_hooks_test.lg`, `agent_test.lg` (unknown tool, argument validation), `agent_error_wire_test.lg` (tool failure returned as error result), `llm_contract_test.lg` (parallel ordered execution), `coding_loop_audit_test.lg` (returned shell errors, full error events and custom override semantics) |
| 9.4 Execution environment | `environment_contract_test.lg` (interface, 10s default, per-call timeout, SIGTERM then SIGKILL, secret filtering, custom environments), `execution_*_test.lg`, `execution_scope_test.lg` (child ownership, parent/sibling survival, admission races), `coding_loop_audit_test.lg` (supplied-environment timeout caps) |
| 9.5 Tool output truncation | `tool_output_contract_test.lg` (character then line limits, marker, full output in events, overrides), `agent_parity_matrix_wire_test.lg` (large read on the wire) |
| 9.6 Steering | `coding_loop_audit_test.lg` (reentrant drain retention), `agent_loop_contract_test.lg`, `agent_loop_wire_test.lg` (steering message as the next user turn on the wire) |
| 9.7 Reasoning effort | `agent_loop_wire_test.lg` (effort change on the next request), `llm_test.lg` (translation per provider) |
| 9.8 System prompts | `project_docs_contract_test.lg`, `prompt_metadata_test.lg`, `profiles_test.lg` |
| 9.9 Subagents | `subagent_lifecycle_test.lg`, `agent_subagent_wire_test.lg`, `coding_loop_audit_test.lg` and `execution_scope_test.lg` (local child cancellation and isolation; custom environments need `:fork_scope`) |
| 9.10 Event system | `agent_test.lg` (stamps, delivery, lifecycle), `agent_loop_wire_test.lg`, `agent_error_wire_test.lg` (terminal order), `agent_event_origin_test.lg`. `event_families_test.lg` covers pipeline events, not coding-agent events. No streaming-tool output-delta emitter exists; see the current audit's applicability discussion. |
| 9.11 Error handling | `agent_error_wire_test.lg` (429/503 retried, auth fatal), `session_error_contract_test.lg` (context overflow warning), `turn_ownership_test.lg` (shutdown sequence) |
| 9.12 Parity matrix | **Live coverage with explicit gateway provenance.** `lgx live-coding-conformance` runs all fifteen rows per native provider. Anthropic `claude-fable-5-1` passes 15/15 across the initial 13-row pass and a corrected-prompt two-row rerun; assertions were unchanged. Gemini also passes 15/15 across its repaired full run and targeted loop-warning rerun. First-party OpenAI is wire verified, direct live not run, explicitly accepted by the user for publication. OpenRouter `openai/gpt-5.2` covers 15/15 across three runs using Responses and the OpenAI profile. See [current provider evidence](provider-model-audits.md#live-coding-conformance-follow-up--2026-09-27). Scripted adapters remain deterministic evidence, not substitutes for these live cells. |
| 9.13 Integration smoke | **Implemented, live evidence partial.** `coding_smoke_journey.lg` retains one session across seven steps; `coding_smoke_journey_test.lg` includes negative proof controls. Initial weaker Anthropic smoke evidence is excluded. The strengthened Anthropic smoke passed five steps, then hit quota-exceeded in the subagent step; timeout remained unrun. Gemini strengthened smoke passes all seven steps; First-party OpenAI wire evidence is accepted for publication; direct live is not run. OpenRouter Responses smoke passes 7/7. Anthropic's profile default is explicitly capped to ten seconds. |

Audit 2026-09-12: historical 8/8 gateway runs used generic profiles for registry
aliases. They establish transport behavior, not native profile parity. The live
runner now selects tools and base instructions by protocol and preserves the
configured alias for request routing. New recovery checks require a failed read
followed by a successful read in a later tool round and the recovered file.
Editing checks require the profile's dedicated tool and the exact resulting file.

Focused live follow-up: Responses/GPT-4.1-mini passed both new rows on repeat;
the first editing attempt failed. Messages/Haiku-4.5 passed editing and failed
recovery's exact-file criterion. These results leave model reliability and the
full matrix open. Generated reports remain local under `evidence/`; see
[verification output](verification.md) for retention and reproduction.

Run all deterministic audit checks with `lgx audit-coding-loop`. For a focused
namespace, use `lgx test-ns attractor.agent-parity-matrix-wire-test` (or another
mapped namespace). Select live rows with `ATTRACTOR_PARITY_ROWS`; see
[verification](verification.md).

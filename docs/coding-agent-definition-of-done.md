# Coding agent loop: definition-of-done evidence

Every checklist block of the upstream coding-agent-loop spec mapped to the
test that proves it on the local runtime. "Wire" means a real session drives
the provider's actual HTTP adapter against `test/fixtures/provider_wire_server.lg`.
Verified 2026-09-10, full suite 916 tests / 8733 assertions / 0 failures.

| Block | Evidence |
|---|---|
| 9.1 Core loop | `agent_loop_contract_test.lg` (sequential inputs, round and turn limits, follow-up), `agent_loop_wire_test.lg` (wire tool turn), `turn_ownership_test.lg` (abort kills processes, CLOSED), `agent_test.lg` loop detection |
| 9.2 Provider profiles | `profiles_test.lg` (tool sets, schemas, system prompts, custom registration and override), `agent_loop_wire_test.lg` (prompt and tools on the wire) |
| 9.3 Tool execution | `tool_hooks_test.lg`, `agent_test.lg` (unknown tool, argument validation), `agent_error_wire_test.lg` (tool failure returned as error result), `llm_contract_test.lg` (parallel ordered execution) |
| 9.4 Execution environment | `environment_contract_test.lg` (interface, 10s default, per-call timeout, SIGTERM then SIGKILL, secret filtering, custom environments), `execution_*_test.lg` |
| 9.5 Tool output truncation | `tool_output_contract_test.lg` (character then line limits, marker, full output in events, overrides), `agent_parity_matrix_wire_test.lg` (large read on the wire) |
| 9.6 Steering | `agent_loop_contract_test.lg`, `agent_loop_wire_test.lg` (steering message as the next user turn on the wire) |
| 9.7 Reasoning effort | `agent_loop_wire_test.lg` (effort change on the next request), `llm_test.lg` (translation per provider) |
| 9.8 System prompts | `project_docs_contract_test.lg`, `prompt_metadata_test.lg`, `profiles_test.lg` |
| 9.9 Subagents | `subagent_lifecycle_test.lg`, `agent_subagent_wire_test.lg` |
| 9.10 Event system | `event_families_test.lg`, `agent_loop_wire_test.lg`, `agent_error_wire_test.lg` (terminal order) |
| 9.11 Error handling | `agent_error_wire_test.lg` (429/503 retried, auth fatal), `session_error_contract_test.lg` (context overflow warning), `turn_ownership_test.lg` (shutdown sequence) |
| 9.12 Parity matrix | `agent_parity_matrix_wire_test.lg`: every row for openai, anthropic and gemini with a scripted model through the real adapters; live rows via `make live-parity` (`test/live/parity_matrix.lg`): 8/8 on `llamacpp/qwen3.8-27b`; native OpenAI/Anthropic/Gemini cells await funded keys |

Focused run of any row: `make run-<namespace>`, e.g. `make run-agent_parity_matrix_wire`.

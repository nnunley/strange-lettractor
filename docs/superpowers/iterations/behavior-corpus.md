# Behavior Evidence Corpus

Commands are run from the repository root with let-go 1.12.2 or newer. Pending local commands first require a stable scenario marker in the named test file and therefore fail until evidence is implemented; they cannot turn green from unrelated tests. Live commands likewise require the dedicated runner.

| Scenario | Seam | Cadence | Command | State |
|---|---|---|---|---|
| SCN-ATTR-PARSE | parser integration | sentinel | `LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in full suite; excludes label-after-node |
| SCN-ATTR-ENGINE | engine integration | sentinel | `LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in full suite |
| SCN-TIMEOUT | engine/agent integration | sentinel | `LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in full suite |
| SCN-CHECKPOINT | engine integration | sentinel | `LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in full suite |
| SCN-SUBGRAPH-LABEL | parser/stylesheet integration | impacted | `rg -q '^;; SCN-SUBGRAPH-LABEL COMPLETE$' test/attractor/lifecycle_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/lifecycle_contract_test.lg` | passing in ITER-0002 |
| SCN-PUBLIC-LIFECYCLE | public pipeline/CLI/server integration | impacted | `rg -q '^;; SCN-PUBLIC-LIFECYCLE COMPLETE$' test/attractor/lifecycle_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/lifecycle_contract_test.lg` | passing in ITER-0002 |
| SCN-STATUS-FILE | engine integration | impacted | `rg -q '^;; SCN-STATUS-FILE COMPLETE$' test/attractor/status_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in ITER-0001 |
| SCN-AUTO-STATUS | parser/engine integration | impacted | `rg -q '^;; SCN-AUTO-STATUS COMPLETE$' test/attractor/status_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in ITER-0001 |
| SCN-CONTEXT-ISOLATION | context integration | impacted | `rg -q '^;; SCN-CONTEXT-ISOLATION COMPLETE$' test/attractor/context_isolation_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/context_isolation_contract_test.lg` | pending ITER-0003 |
| SCN-PIPELINE-COMPOSITION | engine end to end | impacted | `rg -q 'SCN-PIPELINE-COMPOSITION' test/attractor/lifecycle_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0004 |
| SCN-VALIDATION | validation/engine integration | impacted | `rg -q '^;; SCN-VALIDATION COMPLETE$' test/attractor/lifecycle_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/lifecycle_contract_test.lg` | passing in ITER-0002 |
| SCN-LOOP-RESTART | engine integration | impacted | `rg -q '^;; SCN-LOOP-RESTART COMPLETE$' test/attractor/loop_restart_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/loop_restart_contract_test.lg` | pending ITER-0003 |
| SCN-TRANSFORM-ORDER | transform/validation integration | impacted | `rg -q '^;; SCN-TRANSFORM-ORDER COMPLETE$' test/attractor/lifecycle_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/lifecycle_contract_test.lg` | passing in ITER-0002 |
| SCN-FIRST-SUCCESS | concurrency integration | impacted | `rg -q 'SCN-FIRST-SUCCESS' test/attractor/interactive_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0005 |
| SCN-HUMAN-TIMEOUT | interviewer integration | impacted | `rg -q 'SCN-HUMAN-TIMEOUT' test/attractor/interactive_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0005 |
| SCN-ARTIFACT-DISCOVERY | engine/artifact integration | impacted | `rg -q 'SCN-ARTIFACT-DISCOVERY' test/attractor/interactive_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0005 |
| SCN-FANIN-RANKING | handler/LLM integration | impacted | `rg -q 'SCN-FANIN-RANKING' test/attractor/interactive_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0005 |
| SCN-HANDLER-MATRIX | engine integration | impacted | `rg -q 'SCN-HANDLER-MATRIX' test/attractor/interactive_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0005 |
| SCN-INTERVIEWERS | interviewer integration | impacted | `rg -q 'SCN-INTERVIEWERS' test/attractor/interactive_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0005 |
| SCN-CAL-LOOP | coding-loop integration | impacted | `rg -q 'SCN-CAL-LOOP' test/attractor/agent_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0006 |
| SCN-CAL-PROFILES | profile contract | impacted | `rg -q 'SCN-CAL-PROFILES' test/attractor/agent_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0006 |
| SCN-CAL-TOOLS | coding-loop integration | impacted | `rg -q 'SCN-CAL-TOOLS' test/attractor/agent_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0006 |
| SCN-CAL-SUBAGENTS | coding-loop integration | impacted | `rg -q 'SCN-CAL-SUBAGENTS' test/attractor/agent_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0006 |
| SCN-TOOL-HOOKS | coding-loop integration | impacted | `rg -q 'SCN-TOOL-HOOKS' test/attractor/agent_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0006 |
| SCN-SSE-LIVE | HTTP integration | impacted | `rg -q 'SCN-SSE-LIVE' test/attractor/server_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0007 |
| SCN-EVENT-FAMILIES | engine/server integration | impacted | `rg -q 'SCN-EVENT-FAMILIES' test/attractor/server_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0007 |
| SCN-CAL-FAILURE-SHUTDOWN | coding-loop integration | impacted | `rg -q 'SCN-CAL-FAILURE-SHUTDOWN' test/attractor/server_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0007 |
| SCN-CAL-ENV | environment integration | impacted | `rg -q 'SCN-CAL-ENV' test/attractor/prompt_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0008 |
| SCN-CAL-TRUNCATION | coding-loop integration | impacted | `rg -q 'SCN-CAL-TRUNCATION' test/attractor/prompt_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0008 |
| SCN-SYSTEM-PROMPT-BOUND | prompt-builder integration | impacted | `rg -q 'SCN-SYSTEM-PROMPT-BOUND' test/attractor/prompt_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0008 |
| SCN-FAIL-RETRY-CONTRACT | engine integration | impacted | `rg -q 'SCN-FAIL-RETRY-CONTRACT' test/attractor/prompt_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0008 |
| SCN-ULLM-CANCEL | local HTTP integration | impacted | `rg -q 'SCN-ULLM-CANCEL' test/attractor/llm_transport_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0009 |
| SCN-ULLM-HTTP-ERRORS | local HTTP integration | impacted | `rg -q 'SCN-ULLM-HTTP-ERRORS' test/attractor/llm_transport_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0009 |
| SCN-ULLM-CLIENT | client integration | impacted | `rg -q 'SCN-ULLM-CLIENT' test/attractor/llm_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0010 |
| SCN-ULLM-HIGHLEVEL | high-level API integration | impacted | `rg -q 'SCN-ULLM-HIGHLEVEL' test/attractor/llm_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0010 |
| SCN-ULLM-TOOLS | client/tool integration | impacted | `rg -q 'SCN-ULLM-TOOLS' test/attractor/llm_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0010 |
| SCN-ULLM-ADAPTERS | recording-server contract | impacted | `rg -q 'SCN-ULLM-ADAPTERS' test/attractor/llm_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0010 |
| SCN-OPENAI-COMPAT | local HTTP integration | impacted | `rg -q 'SCN-OPENAI-COMPAT' test/attractor/llm_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0010 |
| SCN-ATTR-SMOKE-LIVE | end to end | release/manual residual | `test -x scripts/test-live-providers && LIVE_LLM_TESTS=1 scripts/test-live-providers attractor-smoke` | pending ITER-0011; requires credentials |
| SCN-PROVIDER-MATRIX | live provider contract | release/manual residual | `test -x scripts/test-live-providers && LIVE_LLM_TESTS=1 scripts/test-live-providers provider-matrix` | pending ITER-0011; requires credentials |

Build/AOT release check: `LGX_LG=/Users/ndn/development/let-go/lg lgx build`.

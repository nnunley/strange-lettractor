# Behavior Evidence Corpus

Commands are run from the repository root with the configured local compiler at `/Users/ndn/development/let-go/lg`; `lgx.edn` requires let-go 1.12.2 or newer. Pending local commands first require a stable scenario marker in the named test file and therefore fail until evidence is implemented; they cannot turn green from unrelated tests. Live commands likewise require the dedicated runner.

| Scenario | Seam | Cadence | Command | State |
|---|---|---|---|---|
| SCN-ATTR-PARSE | parser integration | sentinel | `LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in full suite; excludes label-after-node |
| SCN-ATTR-ENGINE | engine integration | sentinel | `LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in full suite |
| SCN-TIMEOUT | engine/agent integration | sentinel | `LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in full suite |
| SCN-CHECKPOINT | engine integration | sentinel | `LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in full suite |
| SCN-PINNED-RECOVERY | public pipeline/checkpoint/server integration | impacted | `rg -q '^;; SCN-PINNED-RECOVERY COMPLETE$' test/attractor/workflow_recovery_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/workflow_recovery_contract_test.lg` | passing ITER-0004; 52 tests / 481 assertions |
| SCN-SUBGRAPH-LABEL | parser/stylesheet integration | impacted | `rg -q '^;; SCN-SUBGRAPH-LABEL COMPLETE$' test/attractor/lifecycle_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/lifecycle_contract_test.lg` | passing in ITER-0002 |
| SCN-PUBLIC-LIFECYCLE | public pipeline/CLI/server integration | impacted | `rg -q '^;; SCN-PUBLIC-LIFECYCLE COMPLETE$' test/attractor/lifecycle_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/lifecycle_contract_test.lg` | passing in ITER-0002 |
| SCN-STATUS-FILE | engine integration | impacted | `rg -q '^;; SCN-STATUS-FILE COMPLETE$' test/attractor/status_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in ITER-0001 |
| SCN-AUTO-STATUS | parser/engine integration | impacted | `rg -q '^;; SCN-AUTO-STATUS COMPLETE$' test/attractor/status_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | passing in ITER-0001 |
| SCN-CONTEXT-ISOLATION | context integration | impacted | `rg -q '^;; SCN-CONTEXT-ISOLATION COMPLETE$' test/attractor/context_isolation_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/context_isolation_contract_test.lg` | passing in ITER-0003 |
| SCN-PIPELINE-COMPOSITION | public pipeline/engine/checkpoint integration | impacted | `rg -q '^;; SCN-PIPELINE-COMPOSITION COMPLETE$' test/attractor/composition_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | audited ITER-0005; full suite 473/3370/0 includes configuration, capture, selected-plan, mapped, and nested contracts; ATTR-READ-01 remains separate and failing |
| SCN-VALIDATION | validation/engine integration | impacted | `rg -q '^;; SCN-VALIDATION COMPLETE$' test/attractor/lifecycle_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/lifecycle_contract_test.lg` | passing in ITER-0002 |
| SCN-LOOP-RESTART | engine integration | impacted | `rg -q '^;; SCN-LOOP-RESTART COMPLETE$' test/attractor/loop_restart_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/loop_restart_contract_test.lg` | passing in ITER-0003 |
| SCN-TRANSFORM-ORDER | transform/validation integration | impacted | `rg -q '^;; SCN-TRANSFORM-ORDER COMPLETE$' test/attractor/lifecycle_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/lifecycle_contract_test.lg` | passing in ITER-0002 |
| SCN-FIRST-SUCCESS | public pipeline/native concurrency integration | impacted | `rg -q '^;; SCN-FIRST-SUCCESS COMPLETE$' test/attractor/parallel_join_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/parallel_join_contract_test.lg` | reviewed ITER-0006 component; 18 tests / 215 assertions; full default suite 491/3585/0; iteration remains incomplete |
| SCN-HUMAN-TIMEOUT | interviewer integration | impacted | `rg -q 'SCN-HUMAN-TIMEOUT' test/attractor/interactive_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0006 |
| SCN-ARTIFACT-DISCOVERY | engine/artifact integration | impacted | `rg -q 'SCN-ARTIFACT-DISCOVERY' test/attractor/interactive_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0006 |
| SCN-FANIN-RANKING | public pipeline/LLM/checkpoint integration | impacted | `rg -q '^;; SCN-FANIN-RANKING COMPLETE$' test/attractor/fan_in_pipeline_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/fan_in_pipeline_contract_test.lg` | established: 4 tests / 110 assertions; scoped component only |
| SCN-HANDLER-MATRIX | engine registry/dispatch integration | impacted | `rg -q '^;; SCN-HANDLER-MATRIX COMPLETE$' test/attractor/handler_matrix_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/handler_matrix_contract_test.lg` | established: 5 tests / 324 assertions; dispatch seam, not handler internals |
| SCN-INTERVIEWERS | interviewer integration | impacted | `rg -q 'SCN-INTERVIEWERS' test/attractor/interactive_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0006 |
| SCN-CAL-LOOP | coding-loop integration | impacted | `rg -q 'SCN-CAL-LOOP' test/attractor/agent_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0007 |
| SCN-CAL-PROFILES | profile contract | impacted | `rg -q 'SCN-CAL-PROFILES' test/attractor/agent_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0007 |
| SCN-CAL-TOOLS | coding-loop integration | impacted | `rg -q 'SCN-CAL-TOOLS' test/attractor/agent_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0007 |
| SCN-CAL-SUBAGENTS | coding-loop integration | impacted | `rg -q 'SCN-CAL-SUBAGENTS' test/attractor/agent_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0007 |
| SCN-TOOL-HOOKS | coding-loop integration | impacted | `rg -q 'SCN-TOOL-HOOKS' test/attractor/agent_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0007 |
| SCN-SSE-LIVE | HTTP integration | impacted | `rg -q 'SCN-SSE-LIVE' test/attractor/server_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0008 |
| SCN-EVENT-FAMILIES | engine/server integration | impacted | `rg -q 'SCN-EVENT-FAMILIES' test/attractor/server_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0008 |
| SCN-CAL-FAILURE-SHUTDOWN | coding-loop integration | impacted | `rg -q 'SCN-CAL-FAILURE-SHUTDOWN' test/attractor/server_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0008 |
| SCN-CAL-ENV | environment integration | impacted | `rg -q 'SCN-CAL-ENV' test/attractor/prompt_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0009 |
| SCN-CAL-TRUNCATION | coding-loop integration | impacted | `rg -q 'SCN-CAL-TRUNCATION' test/attractor/prompt_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0009 |
| SCN-SYSTEM-PROMPT-BOUND | prompt-builder integration | impacted | `rg -q 'SCN-SYSTEM-PROMPT-BOUND' test/attractor/prompt_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0009 |
| SCN-FAIL-RETRY-CONTRACT | engine integration | impacted | `rg -q 'SCN-FAIL-RETRY-CONTRACT' test/attractor/prompt_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0009 |
| SCN-ULLM-CANCEL | local HTTP integration | impacted | `rg -q 'SCN-ULLM-CANCEL' test/attractor/llm_transport_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0010 |
| SCN-ULLM-HTTP-ERRORS | local HTTP integration | impacted | `rg -q 'SCN-ULLM-HTTP-ERRORS' test/attractor/llm_transport_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0010 |
| SCN-ULLM-CLIENT | client integration | impacted | `rg -q 'SCN-ULLM-CLIENT' test/attractor/llm_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0011 |
| SCN-ULLM-HIGHLEVEL | high-level API integration | impacted | `rg -q 'SCN-ULLM-HIGHLEVEL' test/attractor/llm_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0011 |
| SCN-ULLM-TOOLS | client/tool integration | impacted | `rg -q 'SCN-ULLM-TOOLS' test/attractor/llm_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0011 |
| SCN-ULLM-ADAPTERS | recording-server contract | impacted | `rg -q 'SCN-ULLM-ADAPTERS' test/attractor/llm_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0011 |
| SCN-OPENAI-COMPAT | local HTTP integration | impacted | `rg -q 'SCN-OPENAI-COMPAT' test/attractor/llm_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test` | pending ITER-0011 |
| SCN-ATTR-SMOKE-LIVE | end to end | release/manual residual | `test -x scripts/test-live-providers && LIVE_LLM_TESTS=1 scripts/test-live-providers attractor-smoke` | pending ITER-0012; requires credentials |
| SCN-PROVIDER-MATRIX | live provider contract | release/manual residual | `test -x scripts/test-live-providers && LIVE_LLM_TESTS=1 scripts/test-live-providers provider-matrix` | pending ITER-0012; requires credentials |

Additional full-goal residual gates from the ITER-0005 audit:

- `SCN-GRAPH-MERGE`: `rg -q '^;; SCN-GRAPH-MERGE COMPLETE$' test/attractor/lifecycle_contract_test.lg && LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/lifecycle_contract_test.lg` — pending valid nodes-and-edges merge execution proof.
- `SCN-CLOJURE-READER`: `/Users/ndn/development/let-go/lg -source-paths src:. compat/run_mapping.lg` — currently 1 test / 5 failed assertions / exit 1. This is failing acceptance evidence, not a skip or pass; broader artifact-reader checks must accompany restoration.

Build/AOT release check: `LGX_LG=/Users/ndn/development/let-go/lg lgx build`.

# Coding Agent Loop Requirements

OpenRouter follow-up: user-requested `or-responses/openai/gpt-5.2` checks use
the OpenAI Responses adapter/profile with gateway provenance. Combined parity
coverage is 15/15 across initial, targeted and final runs; the final strengthened
same-session smoke passes 7/7. Report `1790550366776` completes its selected
reasoning-change plus smoke scope (exit 0). This supplements accepted first-party OpenAI wire evidence without
claiming direct OpenAI live access. See the current provider evidence.

2026-09-27 live follow-up: `lgx live-coding-conformance` now combines all
fifteen parity rows and the implemented seven-step same-session smoke, with
explicit provider/check/row scope and native-origin validation. Anthropic has
15/15 parity coverage across an initial 13-row pass and a targeted two-row rerun
after clarifying exact-output prompts (assertions unchanged). Gemini also covers
15/15 across its repaired full run and targeted loop-warning rerun. Strengthened
Anthropic smoke passes five steps before quota-exceeded in the subagent step;
timeout remains unrun. Gemini strengthened smoke passes all seven steps. Initial
weaker smoke evidence is excluded. First-party OpenAI is wire verified, direct live not run, and
explicitly accepted by the user for publication without a push blocker. See
[current provider
evidence](../../../provider-model-audits.md#live-coding-conformance-follow-up--2026-09-27).
The current named audit includes these follow-ups. The earlier full-suite count
below remains dated repair evidence, not final publication verification.

2026-09-27: the [original-spec audit](../../../coding-loop-audit-2026-09-27.md)
found four defects that are now repaired with regular regression tests.
`lgx audit-coding-loop` passes 261 tests / 2529 assertions with zero failures or
errors. Earlier repair full suite passed 1566 tests / 14159 assertions with zero failures; live parity and shared-session
smoke remain unproved. Custom environments need optional `:fork_scope` for
independently owned child cancellation. The rows below describe this repair
without changing historical component evidence into a completion claim.

2026-09-24: ITER-0020 is reviewed and integrated. All fifteen live row functions
exist; the five added journeys use the same CLI/test entry point through all
three native scripted protocols, real local effects and causal/identity/path
failure controls. Focused 11/156/0; final integrated suite 1498/13585/0; paired
specification, quality and progress audits plus compiled CLI gates pass.
CAL-PARITY-01 remains partial for first-party live results. Gemini/Anthropic
native provider subsets now pass after user funding and ITER-0021's integrated
Gemini/Anthropic signed-history repair (full suite1526/13863/0). A native lookup
agent turn succeeds on each catalog default; Gemini signatures and a separate
Fable high-reasoning thinking-block continuation are verified. The full fifteen
coding-agent parity rows have not been run against all first-party accounts.

2026-09-23 closure update: CAL-ENV-01/CAL-TOOLS-01 now include native session
editing on standard-only custom environments. Profile tools own raw-file
presentation, generic edits retain complete contents, and patch capability
checks precede mutations. See [runtime/agent audit](../2026-09-23-runtime-agent-audit.md)
and [closure evidence](../spec-closure.md). CAL-PARITY-01 remains partial:
the live runner still lacks five of the fifteen required rows.

Source: [`specs/coding-agent-loop-spec.md`](../../../../specs/coding-agent-loop-spec.md)

Audit correction 2026-09-12: the historical “full matrix” claim below is
superseded. The cited matrix test covers eight of fifteen rows. The live runner
now covers ten, and previously used generic profiles for transport aliases.
See `docs/coding-agent-definition-of-done.md` for current coverage and limitations.
Generated report paths below refer to ignored local output; see
`docs/verification.md` for retention policy.

| Story | Status | Requirement and acceptance proof |
|---|---|---|
| CAL-AUDIT-01 | repaired:deterministic | P1, §§2.8/7.2/9.9: local child scopes terminate and join owned shell processes/descendants without closing parent or siblings. `coding_loop_audit_test.lg` and `execution_scope_test.lg` prove cancellation, survival, cleanup/admission races and retained working-directory ownership. Custom environments require optional `:fork_scope` for independent cancellation. Named audit: 261/2529/0; earlier repair full suite 1566/14159/0. |
| CAL-AUDIT-02 | repaired:deterministic | P2, §§2.6/9.6: atomic batch detach preserves steering accepted during drain callbacks. `coding_loop_audit_test.lg` verifies history and next model request receive the accepted message once. Named audit: 261/2529/0; earlier repair full suite 1566/14159/0. |
| CAL-AUDIT-03 | repaired:deterministic | P2, §9.3/Appendix B: native shell nonzero exits/timeouts/cancellation classify as errors; full raw events and model-only truncation are preserved. `coding_loop_audit_test.lg` also protects custom replacement semantics. Named audit: 261/2529/0; earlier repair full suite 1566/14159/0. |
| CAL-AUDIT-04 | repaired:deterministic | P2, §§4.1/5.4: native shell clamps per-call/profile-default timeout before invoking supplied local or custom environments. `coding_loop_audit_test.lg` verifies all three profiles, defaults, explicit overrides and local execution. Named audit: 261/2529/0; earlier repair full suite 1566/14159/0. |
| CAL-OWN-01 | done:ITER-0008 component | Fence cancellation/failure cleanup by current root invocation ownership across the idle/completion-callback handoff, including direct successors and newly published session adoption. Atomic close claims preserve B's controller/resources/history/hooks/cache; queued follow-ups retain ownership; explicit public shutdown remains session-wide. `SCN-CAL-TURN-OWNERSHIP`: 5 tests / 85 assertions; full suite 644/5970. See `evidence/turn-ownership-evidence.edn`; coding-agent §2.3/§2.8. Broader shutdown/ITER-0008 remains incomplete. |
| CAL-LOOP-01 | done:component | Execute the model/tool loop over sequential inputs, maintain history, emit all lifecycle events, terminate on final content/max turns, detect repeated-tool loops, and continue via `follow_up` ([§2](../../../../specs/coding-agent-loop-spec.md#2-agentic-loop)). `SCN-CAL-LOOP` now has deterministic unified-client session integration (3 tests / 43 assertions), including tool-result continuation, normal event order, per-input and cumulative limits, steering and queued follow-up. Streaming/error/shutdown completeness and native/live evidence remain separately pending; this is not full §2 conformance. 2026-09-08: native-wire parity in `agent_loop_wire_test.lg` (streamed tool turn through the real openai/anthropic/gemini adapters against the recording server). Live-provider runs remain under `SCN-PROVIDER-MATRIX`. |
| CAL-REASON-01 | done:component | Apply configured reasoning effort and allow safe mid-session changes without corrupting provider reasoning/tool ordering ([§2.7](../../../../specs/coding-agent-loop-spec.md#27-reasoning-effort)). `agent_loop_contract_test.lg` verifies a low-to-high change during tool execution reaches the next unified-client request while retained assistant reasoning and tool-result ordering agree. Native-provider wire parity remains pending. 2026-09-08: `agent_loop_wire_test.lg` observes the low-to-high change on the second wire request (`reasoning.effort`) after tool-result and steering ordering. |
| CAL-PROFILE-01 | done:component | OpenAI, Anthropic, Gemini, and custom profiles expose correct model, tools, system prompt, reasoning, and wire options. Fixture tests exist; native payload snapshots/live contracts remain. 2026-09-08: wire snapshots in `agent_loop_wire_test.lg` (`SCN-CAL-PROFILES WIRE COMPLETE`). |
| CAL-TOOLS-01 | done:component | Built-in filesystem, edit, shell, search, and subagent tools execute with documented schemas, bounded output, cancellation, and per-family raw-event-versus-truncated-model evidence. Exact whitespace edit targets work through real Anthropic/Gemini profile executors (2 tests / 32 assertions). `SCN-CAL-READ-FILE` verifies local text/binary behavior and PNG/JPEG/GIF/WebP signature classification; representative PNG attachments traverse each actual agent/provider request encoder, with PNG/GIF in Gemini batch continuation. Native hooks/events, truncation and legacy SDK compatibility are covered: focused/bundle 14/439, impacted 217/1667, default suite 667/6507, zero failures. See `evidence/read-file-contract-evidence.edn`; paired component audit clean. Other formats, live model acceptance and remaining tool contracts are not closed by this component. Close the full requirement with `SCN-CAL-TOOLS` and `SCN-CAL-TRUNCATION`. 2026-09-10: `SCN-CAL-TOOLS` complete in `tool_contract_test.lg` (8/103/0): every profile tool executed for real with offset/limit numbering, parent creation, uniqueness/replace_all, v4a add/update and containment, shell status/timeout, grep options, glob ordering, Gemini list_dir/read_many_files. Live model acceptance of tool schemas is covered per provider by `SCN-PROVIDER-MATRIX`. |
| CAL-ENV-01 | done | Local, custom, and composed execution environments return exact exit status/duration/stdout/stderr/cancellation fields, reject invalid requests, and filter secrets from child environments ([§4](../../../../specs/coding-agent-loop-spec.md#4-tool-execution-environment)). Explicit caller environment values no longer overwrite wrapper command/launcher/deadline state: native/bundle 3/20, full suite 725/7012/0. See `docs/command-env-isolation.md` for evidence and inherited-name/relative-working-directory/Windows residuals; full `SCN-CAL-ENV` remains open. 2026-09-08: `SCN-CAL-ENV` complete in `environment_contract_test.lg` (15/117/0, three runs): exact ExecResult/DirEntry fields, separate stdout/stderr (wrapper job-notice leak fixed in `execution.lg`), timeout/cancel/closed contracts, four policies with case-insensitive secret filtering, composed environments. Windows shell residual remains out of scope. |
| CAL-TRUNC-01 | done:component | `tool_output_contract_test.lg` proves raw event/model-output separation through real session and unified-client boundaries (5 tests / 174 assertions): independent eight-tool default limits/modes, default line limits, character-before-line order, 10 MiB single-line and two 10 MiB lines, configuration override, and bounded exceptions/unknown-tool errors with full raw event errors. Stored results equal the next model request. Controlled executors isolate output handling; native tool execution and streaming remain separate requirements. `SCN-CAL-TRUNCATION`. |
| CAL-STEER-01 | done:component | Steering messages enter at the next safe turn and preserve provider reasoning/tool-call ordering. Unit proof exists; add native-wire parity. 2026-09-08: on the wire, the steering message is the last turn of the continuation request after the tool result for all three native profiles. |
| CAL-SYSTEM-01 | done:component | `project_docs_contract_test.lg` verifies provider-filtered root-first discovery and the rendered 32 KiB UTF-8 budget (6/30, native/bundle). `prompt_metadata_test.lg` verifies actual two-turn runtime/git snapshots, catalog display names, trusted profile metadata, safe fallbacks, unchanged model routing and final overrides (3/66, native/bundle; full suite 722/6992/0). Provider topic assertions also run in `profiles_test.lg`. See `docs/project-docs-budget.md` and `docs/prompt-model-metadata.md`. Knowledge cutoff is explicitly unknown when unavailable; sourced catalog cutoff coverage remains pending, not silently satisfied by this fallback. 2026-09-10: catalog knowledge cutoffs are recorded only where the vendor publishes one (`docs/model-catalog-sources.md`: Opus 4.6, Haiku 4.5, GPT-5.2, GPT-5.2 Codex); the others stay `unknown`, and `prompt_metadata_test.lg` ties every recorded value to that source note. 2026-09-17: the source now lives on the catalog entry itself (`:knowledge_cutoff_source` in `models.lg`) and the test checks that pairing, so the note (archived under `docs/_archive/`) is history rather than a test dependency. |
| CAL-SUBAGENT-01 | done:component | Subagents have independent histories, depth/turn bounds, inherited cancellation, safe result propagation, and working spawn/`send_input`/wait/close operations ([§7](../../../../specs/coding-agent-loop-spec.md#7-subagents)). Lifecycle ownership component: terminal cancellation, atomic parent/send admission, queued completion handoff and public wait snapshots have 12 tests / 106 assertions; impacted 166/1044 and full suite 679/6613, zero failures. See `evidence/subagent-lifecycle-evidence.edn`; paired final audit clean. Full profile/model/directory/depth/live conformance remains open; this does not close all `SCN-CAL-SUBAGENTS`. 2026-09-10: `agent_subagent_wire_test.lg` closes profile/model/directory/depth conformance on the wire for all three native profiles; live runs stay under `SCN-PROVIDER-MATRIX`. |
| CAL-ERROR-01 | done:component | Classify auth, rate-limit, transport, protocol, cancellation, and tool failures; retry only retryable failures; flush terminal events in order. `SCN-CAL-CONTEXT-RECOVERY` now proves original typed errors, fatal auth/no retry, recoverable context overflow, retained resources/queues and explicit subsequent input (5 tests / 177 assertions; 8 native loopback cases across four adapters). General retry, cancellation joins, terminal flushing and live-provider parity remain pending; see `docs/session-error-contract.md`. 2026-09-10: sessions retry transient provider failures with bounded backoff around the client call (`:retry_policy`, `:llm_retry` event) and `agent_error_wire_test.lg` proves 429/503 recovery, untried authentication closure with ordered terminal events, and tool-failure continuation on the wire for all three native profiles. Cancellation joins are covered by `SCN-CAL-TURN-OWNERSHIP`; live parity stays under `SCN-PROVIDER-MATRIX`. |
| CAL-ENGINE-01 | proved | Engine deadlines propagate through agent loops, tool processes, nested subagents, and parallel/manager children and wait for quiescence. `SCN-TIMEOUT`. |
| CAL-PARITY-01 | partial (full fifteen-row matrix unproved) | Run the same agent-loop contract against OpenAI, Anthropic, and Gemini using opt-in credentials, recording provider/model and pass/fail evidence. `SCN-PROVIDER-MATRIX`. 2026-09-08: the `:agent-loop` journey in `test/live/provider_matrix.lg` runs the native loop per configured provider; passed on openai-compat only. 2026-09-09: `:agent-loop` passed live on OpenRouter and Ollama Cloud through the registry; Anthropic blocked by account balance. 2026-09-10: the full definition-of-done matrix passes deterministically for all three profiles in `agent_parity_matrix_wire_test.lg`; the checklist-to-evidence map is `docs/coding-agent-definition-of-done.md`. Only the live cells wait on funded native keys. 2026-09-10 live: `test/live/parity_matrix.lg` drives the same eight rows with natural-language tasks against a real model; `llamacpp/qwen3.8-27b` on llama.cpp passed 8/8 (`evidence/parity-matrix-evidence.edn`). The first live run exposed that a long prompt-processing wait before the first token was charged to the stream-read scope; the runtime now charges it to the request scope. OpenAI, Anthropic and Gemini cells still await funded native keys. Native-protocol live runs 2026-09-10: `or-responses/openai/gpt-4.1-mini` and `or-messages/anthropic/claude-haiku-4.5` passed 8/8 (`evidence/parity-matrix-evidence/`); Chat Completions runs of Anthropic and Google models via OpenRouter also 8/8. |

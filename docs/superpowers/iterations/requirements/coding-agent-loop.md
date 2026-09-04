# Coding Agent Loop Requirements

Source: [`docs/upstream/strongdm-attractor/coding-agent-loop-spec.md`](../../../upstream/strongdm-attractor/coding-agent-loop-spec.md)

| Story | Status | Requirement and acceptance proof |
|---|---|---|
| CAL-LOOP-01 | partial | Execute the model/tool loop over sequential inputs, maintain history, emit all lifecycle events, terminate on final content/max turns, detect repeated-tool loops, and continue via `follow_up` ([§2](../../../upstream/strongdm-attractor/coding-agent-loop-spec.md#2-agentic-loop)). Unit evidence exists; close with `SCN-CAL-LOOP`. |
| CAL-REASON-01 | partial | Apply configured reasoning effort and allow safe mid-session changes without corrupting provider reasoning/tool ordering ([§2.7](../../../upstream/strongdm-attractor/coding-agent-loop-spec.md#27-reasoning-effort)). Fixture proof exists; add session evidence. |
| CAL-PROFILE-01 | partial | OpenAI, Anthropic, Gemini, and custom profiles expose correct model, tools, system prompt, reasoning, and wire options. Fixture tests exist; native payload snapshots/live contracts remain. |
| CAL-TOOLS-01 | partial | Built-in filesystem, edit, shell, search, and subagent tools execute with documented schemas, bounded output, cancellation, and per-family raw-event-versus-truncated-model evidence. Close with `SCN-CAL-TOOLS` and `SCN-CAL-TRUNCATION`. |
| CAL-ENV-01 | partial | Local, custom, and composed execution environments return exact exit status/duration/stdout/stderr/cancellation fields, reject invalid requests, and filter secrets from child environments ([§4](../../../upstream/strongdm-attractor/coding-agent-loop-spec.md#4-tool-execution-environment)). Core local behavior is proved; close with `SCN-CAL-ENV`. |
| CAL-TRUNC-01 | partial | Preserve full raw tool output in events while presenting bounded head/tail output to the model. Add pathological 10 MB and two-line cases plus a default-limit snapshot. `SCN-CAL-TRUNCATION`. |
| CAL-STEER-01 | partial | Steering messages enter at the next safe turn and preserve provider reasoning/tool-call ordering. Unit proof exists; add native-wire parity. |
| CAL-SYSTEM-01 | partial | Generate repository-aware system prompts with platform, working directory, git metadata, and an explicit bounded/truncated project-instructions section. Add the 32 KB boundary regression. |
| CAL-SUBAGENT-01 | partial | Subagents have independent histories, depth/turn bounds, inherited cancellation, safe result propagation, and working spawn/`send_input`/wait/close operations ([§7](../../../upstream/strongdm-attractor/coding-agent-loop-spec.md#7-subagents)). Local proof is strong; close missing lifecycle/depth evidence with `SCN-CAL-SUBAGENTS`. |
| CAL-ERROR-01 | partial | Classify auth, rate-limit, transport, protocol, cancellation, and tool failures; retry only retryable failures; flush terminal events in order. Add real controllable-server and auth-no-retry session tests. |
| CAL-ENGINE-01 | proved | Engine deadlines propagate through agent loops, tool processes, nested subagents, and parallel/manager children and wait for quiescence. `SCN-TIMEOUT`. |
| CAL-PARITY-01 | missing | Run the same agent-loop contract against OpenAI, Anthropic, and Gemini using opt-in credentials, recording provider/model and pass/fail evidence. `SCN-PROVIDER-MATRIX`. |

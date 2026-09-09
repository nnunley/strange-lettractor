# First Qwen development trial

The first real repository task used the existing let-go DOT engine and native
coding-agent loop with `qwen3.8-27b`, served by llama.cpp. The existing adapter
named `openai-compat` supplied its OpenAI-compatible Chat Completions transport; no
Ollama service was involved. Streaming was disabled for this trial.

Task: preserve a string `reasoning_content` field as normalized response
`:reasoning`, including the empty string; use nil for absent/non-string values.
Keep answer content, tool calls, usage, and raw data unchanged. This also restores
existing high-level generation/step reasoning propagation. Streaming reasoning
normalization was separate, unfinished work at the time of this trial. The later
[deterministic streaming fix](qwen-streaming-reasoning.md) is separate evidence,
not an additional autonomous Qwen development success.

## Outcome: assisted, not autonomous

Two bounded runs each reached 20 model requests. Qwen produced a regression test
and eventually proposed the correct production expression, but could not apply
the exact-match edit: its replacement searches repeatedly had incorrect leading
whitespace. Its first test also lacked a namespace and incorrectly expected a
nested response map. Review feedback helped it correct the test.

Neither DOT run passed its independent deterministic verification stage. Codex
then applied the two-line production change and supplemented Qwen's regression
coverage. Qwen's corrected test failed two assertions before that change.

The worker could modify only the adapter and its new test file, and could execute
only two fixed test commands. These tool allowlists are not an OS sandbox for
arbitrary code executed by tests. The known-good main checkout ran the workflow;
candidate changes lived in a separate `.worktrees` checkout. No private project
notes were included.

## Follow-up breadcrumbs

- Give workers explicit available paths and actionable permission errors.
- Improve exact-edit guidance and mismatch diagnostics without silently relaxing
  edit matching. The generic profile's edit description is currently minimal.
- Bound repeated unsuccessful calls and escalate with the actual tool evidence.
- Preserve a deterministic test gate: reaching the agent turn limit must not be
  interpreted as successful implementation merely because the handler returned.
- Align context budgeting with the server's active context (32,768 in this run),
  not the generic profile's larger default or the model's training maximum.

This trial does not establish unattended self-development readiness or broad
model-quality conclusions.

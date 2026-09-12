# Current development request

Implement unified LLM specification §5.8 tool-call repair in this repository.
When tool arguments fail validation and `repair_tool_call` is configured,
attempt repair, validate the repaired arguments, and execute only a valid call.
If repair is absent or fails, return a tool error to the model.

Cover both `generate` and `stream`, preserving tool-call IDs, result order,
cancellation and the rule that execution failures do not trigger argument repair.
Inspect the current implementation and specification before selecting the callback
contract. Add regression evidence that fails before the implementation change.

Preserve the uncommitted console, retry-policy and stylesheet work. Do not commit
or push. Record changes, test results and remaining questions in
`attractor_runs/repl/handoff.md`.

# Tool-call argument repair

The high-level `generate` and `stream` APIs accept `:repair_tool_call` in their
options. This implements unified LLM specification §5.8 for active tools.

```clojure
{:repair_tool_call
 (fn [original-call validation-error]
   ;; Return a complete call with corrected :arguments, or nil to decline.
   ;; Both parsed maps and JSON strings are accepted as arguments.
   (assoc original-call :arguments {"x" 2}))}
```

The callback receives the original tool call and the exception from JSON parsing
or schema validation. It runs once per invalid call. Its result must preserve
the original ID and tool name, and its arguments must pass the same validation
as the initial call. A nil result, thrown exception, malformed call, changed
identity or invalid repaired arguments becomes a tool error returned to the model.
There is no recursive repair loop. Unknown tools and tool execution exceptions
produce ordinary tool errors without calling the repair callback.

Repairs run within the same bounded concurrent dispatch and owned cancellation
scope as tool execution. Results preserve the original model call order and IDs.
Cancellation is checked before repair, after it returns and before execution;
a callback that signals an abort cannot cause the repaired tool to execute or
another model round to start. As with other custom callbacks, noncooperative work
that ignores cancellation cannot be forcibly interrupted by the Lisp layer.
The callback itself is not forwarded to provider adapters or middleware.

The two-argument callback signature and identity restriction are local API choices;
§5.8 requires repair behavior but does not prescribe a callback signature.

Evidence: `make run-tool_repair`, 6 tests / 128 assertions. Covers both high-level
APIs, invalid JSON/schema, failed repair cases, untouched valid/unknown/executor
failures, overlapping repairs, ordered continuation messages and abort during
repair. The initial four regressions failed 30 assertions before implementation.
Existing LLM contracts pass 83/495 and cancellation ownership passes 9/35.
Final full suite: 937 tests / 8991 assertions / zero failures.

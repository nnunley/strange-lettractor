# Stream accumulator audit

Unified LLM section 4.4 requires accumulation into a Response equivalent to
completion. Section 3.13 permits a finish event without a full response, so the
accumulator must preserve the content it collected from deltas.

The accumulator previously used `str/blank?` when constructing text parts.
Whitespace remained in `:message :text`, but disappeared from `:content` and
`:parts`. It now checks whether text is nonempty, preserving spaces, newlines,
and tabs without inventing a text part for an empty stream.

`test/attractor/stream_accumulator_contract_test.lg` exercises partial responses
and finish events without a full response. Before the fix, nine content
assertions failed; after it, two tests and 17 assertions pass. The existing LLM
namespace also passes 83 tests and 495 assertions.

The high-level streaming implementation exposes the final provider response via
`:response`, current accumulated state via `:partial_response`, and earlier
executed tool-step results in `:step_finish` events. These are distinct surfaces;
the specification does not require the final Response to concatenate all prior
tool-step responses. Existing multi-step tests cover continuation and final text.
This focused audit does not establish complete streaming-spec conformance.

## Structured output without a final response payload

`stream-object` had a related section 3.13 gap: it always parsed
`finish.response`, even when absent. Consequently valid JSON collected from
deltas produced `:no-object-generated` at finalization. It now validates the
collected text when that optional payload is absent, while an explicitly
provided response remains authoritative. Final validation uses the original
text, not the repaired partial object used for progressive display.

`stream_object_contract_test.lg` proves valid split JSON succeeds, malformed
and schema-invalid final text fails, and an explicit final response takes
precedence. Two assertions failed before the change; all three tests and six
assertions pass afterward. The existing LLM namespace (83/495) and build pass.

An additional structured-stream cancellation test opens an adapter stream,
aborts while the consumer is idle, waits for its registered cleanup callback,
and verifies `object()` raises `:abort` rather than returning buffered JSON.
The namespace now passes four tests and nine assertions. This establishes
propagation through the structured wrapper and idle cleanup at the adapter
boundary; it is not a new socket-level cancellation test.

Integrated verification after these changes: `make test` exits 0 with 1071 tests,
9854 assertions, and zero failures. The log is
`/tmp/attractor-shared-transport-suite.log`. This includes the recent usage,
prompt-cache, and Gemini provider-alias regressions as well as the streaming
tests. A passing local suite does not close the live provider matrix or prove
compatibility with an unpatched release runtime.

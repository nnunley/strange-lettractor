# Current Anthropic model request compatibility

The catalog refresh exposed an adapter mismatch: portable reasoning effort was
always translated into legacy enabled thinking with a token budget. Current
Fable 5.1, Opus 5, and Sonnet 5 use adaptive thinking, with effort carried in
`output_config`. Sources: [thinking configuration](https://platform.claude.com/docs/en/build-with-claude/thinking)
and [Fable 5.1 overview](https://platform.claude.com/docs/en/models/fable-5-1/overview).

Catalog capability metadata now selects adaptive request translation for these
three IDs. Explicit native thinking options retain their fields; native output
effort overrides the portable effort, and other output configuration is retained.
Without a portable effort request, the provider's default thinking remains in
effect. Older model entries keep their existing legacy translation.

Fable 5.1's final request rejects forced `any`/`tool` choice as non-retryable
unsupported-tool-choice, and incompatible explicit thinking modes as non-retryable
invalid-request. Validation follows native-option merging, so overrides cannot
bypass these checks. Omitted thinking remains valid because adaptive thinking is
on by default. No live call was made.

Transport fixtures reproduce legacy-budget translation and forwarded invalid
requests, then verify the repaired wire payloads and errors before transport.
Both completion and streaming use the same request builder. The new namespace
passes 4 tests/27 assertions, LLM tests pass 83/496, and build passes.
Log: `/tmp/attractor-modern-anthropic-final-checks.log`.

This is not complete model integration: native-ID aliases used by gateways,
additional effort levels, thinking-block compatibility across model switches,
model-specific sampling controls, and live API behavior still require assessment.
The provider-wide tool-choice capability predicate is still coarse; request
construction enforces the model-specific restriction.

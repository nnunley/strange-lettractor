# Prompt caching

The Anthropic Messages adapter enables automatic cache annotations by default.
It marks the combined system/developer text, the last tool definition, and the
last content block of the penultimate message after adjacent equal roles have
been merged. That penultimate message is the stable conversation prefix;
the latest message remains outside this automatic breakpoint.

Set `:provider_options {:anthropic {:auto_cache false}}` to disable automatic
placement. Explicit native system, message and tool blocks supplied through
provider options keep their `cache_control` annotations. Both keyword and
string map keys are supported. The adapter adds
`prompt-caching-2024-07-31` to the beta header when automatic caching is enabled
or explicit cache markers occur within the supplied options. Custom beta
headers remain present. `auto_cache` is a client option and is not sent in the
request body.

The 2026-09-12 audit found that nested explicit markers were preserved in the
body but did not trigger the beta header with automatic caching disabled.
Detection now traverses nested maps and sequences. Four regressions failed
before the fix; the focused contract now passes 1 test/16 assertions. The full
LLM test namespace passes 83 tests/495 assertions and the CLI builds. Existing
coverage also checks that disabling automatic caching without explicit markers
does not add the caching header.

Usage fields map OpenAI `input_tokens_details.cached_tokens` and Gemini
`cachedContentTokenCount` to `cache_read_tokens`; Anthropic maps
`cache_read_input_tokens` and `cache_creation_input_tokens` to read/write counts.
These mappings and request annotations are distinct from live cache hits.
The live `prompt-cache` journey runs five tool-using turns with a stable long
system prefix and records each completed turn's final-response usage. It
requires a positive cache read on turn two and over 50% on turn five. Anthropic
uses input + cache reads + cache writes as the denominator; OpenAI and Gemini
use their inclusive input count. This preserves the pinned spec's individual
field mappings while following [Anthropic's token-accounting formula](https://platform.claude.com/docs/en/build-with-claude/prompt-caching).

Messages gateway verification on Claude Haiku 4.5 passes: turn five reports
19092 cached tokens out of 19178 total prompt tokens (99.55%). Evidence:
`provider-cache-protocol-evidence.edn`. The same report records the first
Responses failure. The Responses follow-up in
`provider-cache-responses-evidence.edn` reports cache hits on completed turns,
but GPT-4.1 mini claims a later tool result without executing the tool, so the
journey fails before establishing five-turn evidence. Opaque per-turn tool
results prevent predictable output from substituting for execution; the verifier
also checks actual successful tool results. That failed run is not a cache pass.
Gemini native remains unverified.

Responses follow-up: the cache fixture now uses middleware to send a ToolChoice
map with `required` on each turn's initial request and `none` after the tool
result, making tool use a request requirement instead of an optional model
decision. The same five-turn/cache thresholds pass through the Responses
gateway on GPT-4.1: 16256 cached of 16340 prompt tokens on turn five (99.49%).
Evidence: `provider-cache-responses-gpt41-evidence.edn`. This supersedes the
pending Responses cache conclusion above; failed automatic-selection runs
remain preserved. It proves this configured gateway/model path, not direct
first-party endpoints or Gemini caching.

Verifier tests pass 6 tests/34 assertions, covering provider-specific
denominators, missing/invalid counters, absent turn-two hits, incomplete sessions,
and the strict greater-than-50% boundary, along with the earlier tool/reasoning
checks. No whole-suite rerun is claimed for this evidence-only addition.

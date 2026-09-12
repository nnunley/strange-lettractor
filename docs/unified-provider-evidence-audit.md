# Unified provider evidence audit

Audited 2026-09-12 against unified-llm-spec §§8.6, 8.9 and the retained
`provider-matrix-evidence.edn`. Historical records are preserved as observations;
their pass labels are not accepted without checking the predicate used.

The live runner had a false-positive reasoning predicate: it checked arithmetic
and returned `{:reasoning false}`, which the generic runner labeled pass. The
retained OpenAI Responses gateway row contains exactly that result. Neither
reasoning text nor reported reasoning-token usage was required. The runner now
requires positive numeric `usage.reasoning_tokens`; missing, zero, negative and
string values fail with `:missing-reasoning-usage`. Regression: 1 test/8
assertions pass. A text response with reasoning but no usage also fails; usage
without visible reasoning text may pass because providers can hide that text.
The updated live runner was load-checked with an unconfigured provider filter:
it exits 3 (skip), without model calls. No fresh reasoning-token live pass is
claimed by this audit.

| §8.9 requirement | Existing live evidence assessment |
| --- | --- |
| Simple text | Recorded text journeys check requested response content |
| Streaming text | Text-delta and reconstructed-response checks exist |
| Base64 image | Spatial color check passes through Messages gateway; Responses GPT-4.1 mini gives wrong colors; Gemini native pending. See image-content evidence below. |
| URL image | Exact URL serialization and subject/color answers pass through Responses and Messages gateways; Gemini native pending |
| Single tool plus execution | Checks execution and incorporation of supplied result |
| Multiple parallel tools | Passes locally and through Responses/Messages gateway endpoints; Gemini native pending |
| Three or more tool rounds | Passes locally and through Responses/Messages gateway endpoints; Gemini native pending |
| Streaming tools | Passes locally and through Responses/Messages gateway endpoints; Gemini native pending |
| Structured output | Checks required city/country string values |
| Reasoning-token reporting | Responses GPT-5.2 gateway reports 1183 tokens; Messages reports a positive estimate but fails the arithmetic journey; Gemini native pending |
| Invalid key | Authentication category recorded through Responses/Messages gateway endpoints |
| Rate limiting | No live journey in this runner; transport fixtures are distinct evidence |
| Accurate usage | Live normalized/raw comparisons pass for Responses and Messages gateways; Gemini native pending. Optional/raw aggregation fixed; see `usage-aggregation.md`. |
| Prompt caching | Five-turn journey passes through Messages and Responses gateway endpoints; Responses uses explicit required/none tool choice. Gemini native pending. See `prompt-caching.md`. |
| Provider-specific options | Live metadata pass-through checks pass for Responses/Messages gateways; Gemini native pending |

The agent-loop journey is useful additional evidence, but it does not replace
missing rows above. Chat Completions journeys skip image, reasoning and invalid
key regardless of the underlying model. Gateway protocol runs establish those
adapter paths, not direct first-party endpoint operation. Gemini native live
cells remain without credentials. Therefore ULLM-RELEASE-01 is partial, even
though the runner previously printed no failures for its implemented subset.

Next closure work is to implement the missing journeys and exercise them with
appropriate model capabilities, alongside auditing deterministic adapter
coverage. A skipped cell or unsupported model cannot establish its requirement.

## Image-content evidence

The `image-url` journey now sends
`https://upload.wikimedia.org/wikipedia/commons/3/3a/Cat03.jpg` as a URL image,
not inline bytes. The [source page](https://commons.wikimedia.org/wiki/File:Cat03.jpg)
identifies the subject as an orange cat. Attribution: Fir0002/Flagstaffotos;
the source offers [GFDL 1.2](https://www.gnu.org/licenses/old-licenses/fdl-1.2.html)
and [CC BY-NC 3.0](https://creativecommons.org/licenses/by-nc/3.0/). The repository
references the hosted image and does not redistribute its bytes.

The transport observer requires the exact requested URL in the native image
field. The answer must identify both animal and fur color, with case/spacing
normalization; the prompt does not supply either answer. Regression checks
reject missing or substituted URLs, missing answers, and incorrect subject or
color (provider-evidence namespace: 12 tests/75 assertions).

`provider-url-image-evidence.edn` records two live passes: Messages/Claude
Haiku 4.5 and Responses/GPT-4.1 mini both answer `cat, orange`, with URL
serialization verified. This proves successful URL-image requests and expected
answers on those gateway paths; it does not independently witness the provider's
image fetch or exclude prior knowledge of a public fixture. Gemini native is
still unverified. The initial sandbox attempt failed DNS; the retained report
is from the subsequent authorized network run.

The base64 journey now sends a 256x128 RGB PNG containing a red left half and
blue right half, replacing the one-pixel fixture and nonempty-answer check.
The prompt asks for two colors in spatial order without naming them. The
verifier accepts case/spacing differences but rejects reversed colors, one
color, unrelated answers, and absent text. Provider-evidence tests pass 9 tests
and 51 assertions, including eight assertions for this verifier.

The PNG was generated with Go's standard `image/png` encoder and visually
inspected; its base64 bytes are embedded in the native let-go runner. No
generator or external imaging dependency is needed to execute the journey.

Fresh gateway results are retained in `provider-image-content-evidence.edn`:
Messages/Claude Haiku 4.5 answered `red, blue` and passed. Responses/GPT-4.1 mini
answered `orange, lightblue` and failed. The failure is retained; the test was
not relaxed to accept it. This establishes one successful adapter/model path
and a failing observation on the other, not a diagnosed SDK defect or full
image conformance. The initial sandbox run failed DNS; the retained report is
the subsequent network-authorized run.

A diagnostic rerun checks the actual serialized HTTP request before forwarding
it. Each native adapter must contain exactly one image with the original base64
PNG and correct media type in its protocol-specific field. This check runs on
every attempted image request. The verifier tests reject changed and missing
payloads for all three native formats (10 tests/60 assertions overall).

`provider-image-wire-evidence.edn` retains the live result: both Responses and
Messages report `:image_payload_verified true`. Messages again passes; Responses
answers `blue,red` and fails the spatial-order check. This excludes corruption
by our serializer for those requests. It does not distinguish gateway image
processing from model perception, and the earlier failed observation remains
in its separate report. No production serializer change is justified by this
evidence.

## Dependent tool-round evidence

`multi-round-tools` now supplies a token chain whose next random token is only
available from the preceding tool result. The verifier requires the three
successful results in strictly increasing step positions and the terminal
value in the final answer. Batched calls, missing or errored results, and an
unused terminal value fail; verifier tests pass 2 tests/13 assertions including
the reasoning cases. Fixture tokens use `ids/uuid-text`, because this runtime's
plain UUID string conversion includes EDN reader syntax.

The corrected live journey passes on `llamacpp/qwen3.8-27b`:
[retained result](provider-multi-round-local-evidence.edn). This establishes the
local Chat Completions path, not all three native provider matrix cells.
Focused runs can set `ATTRACTOR_MATRIX_JOURNEYS=multi-round-tools` and an
`ATTRACTOR_MATRIX_EVIDENCE` path to preserve the broader historical report.
An empty journey selection exits 3, never success.

## Parallel tool evidence

`parallel-tools` requests two independent tools in the same model response.
Each executor signals its entry and waits for the other executor to enter
before returning its opaque value. Sequential execution cannot pass. The
single permitted tool round prevents later retries from reusing those entry
signals as false evidence. The result verifier also requires both successful
results in the first step and both complete values in the final answer.

The live local-model journey passes on `llamacpp/qwen3.8-27b` in 3357ms:
[retained result](provider-parallel-local-evidence.edn). Regression checks prove
the overlap barrier accepts simultaneous entry and rejects a missing peer;
they also reject split rounds, error results and unused output. The combined
provider evidence checks pass 4 tests/20 assertions. This is local Chat
Completions evidence; the native-provider cells still need equivalent runs.

## Streaming tool evidence

`streaming-tools` checks completed streamed tool arguments against the exact
arguments delivered to the executor, then requires the successful tool result
after that tool-end event. The opaque returned value must appear in text deltas
after the tool step and in the final assembled response. Missing execution,
wrong arguments, reordered events, unused streamed output and mismatched final
output all fail the evidence checks.

Live local llama.cpp verification passes in 3639ms:
[retained result](provider-streaming-tools-local-evidence.edn), including the
ordered event types, tool-end/step-finish positions and returned opaque value.
Combined verifier checks pass 5 tests/26 assertions. As with the other new
journeys, this establishes the local Chat Completions path; native-provider
cells and the remaining image, caching, usage and options rows stay open.

## Responses and Messages tool journeys

Fresh verification runs all three new tool journeys through both native
protocol adapters against OpenRouter's compatible endpoints. All six pass,
with no skips: [retained results](provider-tool-protocol-evidence.edn).
Models: `or-responses/openai/gpt-4.1-mini` and
`or-messages/anthropic/claude-haiku-4.5`. Each result retains its relevant
event sequence, overlapping result values or dependent round indices.

Reproduction uses the credential-free registry overlay
`test/live/openrouter_protocols.edn` via `ATTRACTOR_CONFIG`. It borrows the
existing configured `openrouter` credential with `:api_key_from`, preserving
the Responses and Messages protocol selection. Set
`ATTRACTOR_MATRIX_PROVIDERS=or-responses,or-messages`, model overrides
`ATTRACTOR_OR_RESPONSES_MODEL=openai/gpt-4.1-mini` and
`ATTRACTOR_OR_MESSAGES_MODEL=anthropic/claude-haiku-4.5`, and
`ATTRACTOR_MATRIX_JOURNEYS=parallel-tools,multi-round-tools,streaming-tools`.
Use `ATTRACTOR_MATRIX_EVIDENCE` for the separate report path and run
`lg -source-paths src:test test/live/provider_matrix.lg run`.

This supersedes the pending Responses/Messages statements in the chronological
notes above. Gemini native, direct first-party endpoints and the other matrix
rows remain separate proof obligations.

Integrated verification after the artifact metadata separation, resume-log fix,
retained smoke evidence and new provider journey verifiers: `make test` exits
zero with 1058 tests, 9771 assertions and zero failures. Captured output:
`/tmp/attractor-shared-transport-suite.log`. Live provider runs are separate from
that deterministic suite and are evidenced by the files linked above.

## Reasoning-token follow-up

The reasoning fixture now requests high effort on modular exponentiation,
`7^123 mod 1009`, whose expected residue 353 was independently computed using
integer modular multiplication. The earlier trivial multiplication at low effort
returned zero reasoning tokens even on GPT-5.2, so it did not prove accounting.

Responses gateway verification now passes on `openai/gpt-5.2`, reporting 1183
reasoning tokens with no visible reasoning text:
[retained result](provider-reasoning-responses-evidence.edn). This is direct
evidence of the native Responses usage field being exposed through the client.

Messages gateway verification on Haiku 4.5 reports an estimated 678 reasoning
tokens, but returns the incorrect residue 385, so the complete journey remains
failed: [diagnostic result](provider-reasoning-messages-evidence.edn). The SDK
estimates Anthropic reasoning-token counts from thinking-block text as the
pinned spec requires; this is not a provider-reported exact token breakdown.
The failure is a model arithmetic result, not proof of a transport failure.
Retained diagnostics include final-answer text and usage without copying hidden
thinking blocks. Verifier tests remain 6 tests/34 assertions, passing.

## Provider-options wire evidence

The live `provider-options` journey supplies a generated metadata marker through
the escape hatch and observes the actual serialized request before forwarding
it to the real HTTP transport. Only the selected option fields are retained;
headers and credentials are not recorded. The journey requires both matching
wire fields and a nonempty successful model response.

Responses and Messages gateway checks both pass:
[retained wire options](provider-options-protocol-evidence.edn). Responses uses
`metadata.audit_token`; Messages uses the native `metadata.user_id` field with
a synthetic UUID, not a person's identifier. The implemented Gemini journey
uses a native safety-settings option but still lacks a credentialed live run.
This proves option transmission and request acceptance, not undocumented
server-side effects of metadata. Existing adapter tests separately cover
portable-setting overrides and beta headers. Combined verifier checks pass
8 tests/43 assertions.

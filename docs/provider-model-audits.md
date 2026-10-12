# Provider & Model Audits — Consolidated

## Live coding conformance follow-up — 2026-09-27

`lgx live-coding-conformance` (also `make live-coding-conformance`) runs all
fifteen parity rows plus the seven-step same-session smoke for the three native
providers by default. Explicit configured gateway aliases require an explicit
model and supported native-style protocol; their evidence is labeled gateway. `ATTRACTOR_CODING_PROVIDERS` and `ATTRACTOR_CODING_CHECKS` select scope;
`ATTRACTOR_PARITY_ROWS` narrows parity rows. Reports retain selected checks/rows,
available rows, model, protocol, endpoint and first-party/gateway origin. In-progress
snapshots and missing credentials cannot become completed evidence.

First-party live evidence remains partial; gateway follow-ups are recorded below:

- **Anthropic / `claude-fable-5-1`: 15/15 parity rows across two runs.** Initial
  report `evidence/coding-conformance-1790548362398.edn` passed 13 rows. Parallel
  and steering failed because the model added trailing newlines that their
  prompts had not forbidden. Prompts now request exact contents without a
  newline; strict assertions were unchanged. Targeted report
  `evidence/coding-conformance-1790549204403.edn` passes both rows. This is
  combined coverage, not a claim that the initial full run passed.
- **Gemini / `gemini-3.8-flash`: 15/15 parity rows across two repaired runs.**
  Initial requests were rejected with HTTP 400 because `read_many_files.paths`
  lacked its array item schema. The profile now declares string items, with
  regression coverage. Report `evidence/coding-conformance-1790549303410.edn`
  passes fourteen rows. Loop detection initially failed because the model
  alternated `read_file` and `read_many_files`. Its prompt now explicitly
  requires the identical `read_file` call twice; assertions were unchanged.
  Targeted report `evidence/coding-conformance-1790549464590.edn` passes that
  remaining row. This is combined coverage, not a clean initial full run.
- **First-party OpenAI: wire verified; direct live not run.** The user explicitly accepts the
  existing OpenAI wire-protocol evidence for publication. This is not a push
  blocker and does not become a real-key live result. Earlier generated reports
  retain their historical missing-credential status unchanged.

At the user's request, OpenAI-family live checks also run through OpenRouter:

```sh
ATTRACTOR_CONFIG=test/live/openrouter_protocols.edn \
ATTRACTOR_CODING_PROVIDERS=or-responses \
ATTRACTOR_OR_RESPONSES_MODEL=openai/gpt-5.2 \
lgx live-coding-conformance
```

The existing overlay uses the OpenAI Responses adapter and OpenAI profile,
with OpenRouter credentials and endpoint. This is gateway evidence, not direct
first-party OpenAI access. Initial report
`evidence/coding-conformance-1790549994021.edn` passed 11/15 parity rows and
6/7 smoke steps. Three parity prompts were ambiguous about read limits or exact
newlines; those instructions were clarified without loosening assertions.
The subagent proof checker incorrectly chose the first failed spawn despite a
later successful spawn/wait/write. It now accepts a correlated successful retry
while preserving child identity, owned-write and mutation-test requirements.
Targeted report `evidence/coding-conformance-1790550248198.edn` passes truncation,
error recovery and subagent parity. Reasoning-change still failed because the
model wrote extra literal words; the prompt then gave explicit write-file
arguments. Final report `evidence/coding-conformance-1790550366776.edn` passes
reasoning-change and all **seven strengthened same-session smoke steps**, with
`:aggregate_status :complete`, exit 0, for that selected scope.

Combined OpenRouter coverage is **15/15 parity rows**: eleven initial passes,
three targeted passes and the final reasoning pass. This is not a single clean
full run. The final smoke is one retained-session 7/7 pass. Evidence records
`:protocol :openai-responses`, endpoint `https://openrouter.ai/api/v1` and
`:origin :gateway`; direct first-party OpenAI live access is not claimed.

Anthropic-family checks now also have OpenRouter Messages evidence:

```sh
ATTRACTOR_CONFIG=test/live/openrouter_protocols.edn \
ATTRACTOR_CODING_PROVIDERS=or-messages \
ATTRACTOR_OR_MESSAGES_MODEL=anthropic/claude-haiku-4.5 \
lgx live-coding-conformance
```

Report `evidence/coding-conformance-1790553400499.edn` passed **14/15 parity
rows and all seven strengthened same-session smoke steps**. Steering parity
failed because Haiku asked for clarification before making any tool call. An
unchanged targeted rerun (`1790553772058`) reproduced that response. The prompt
now supplies explicit `write_file` arguments and tells the model to make the
first call before following the next user instruction. Injection, proof checks
and exact file assertions are unchanged. Targeted report
`evidence/coding-conformance-1790553802491.edn` passes steering with injected
instructions, native continuation and verified files (`:aggregate_status
:complete`, exit 0 for that single-row scope).

Combined Messages/Haiku parity coverage is **15/15 across initial and targeted
runs**, not a single clean full run. The initial smoke is a single retained-session
**7/7 pass**, including child-owned tests that reject both output-removal mutants
and observed ten-second timeout recovery. Evidence records `:protocol
:anthropic-messages`, endpoint `https://openrouter.ai/api/v1` and `:origin :gateway`.
This supplies Anthropic-family smoke coverage through OpenRouter; the earlier
first-party Anthropic quota result remains unchanged. The sandbox-only attempt
(`1790552770436`) failed DNS resolution and is excluded from provider evidence.

After the prompt clarification, the fresh named audit passed **261 tests /
2530 assertions, zero failures or errors**, exit 0
(`/tmp/attractor-or-messages-audit.log`).

The same-session smoke is now implemented in
`test/live/coding_smoke_journey.lg`, with deterministic proof controls in
`test/attractor/coding_smoke_journey_test.lg`. It checks one retained session,
actual file/tool effects, full-event versus truncated-request content, steering
order, child-owned tests, parent continuation and timeout recovery. Child tests
must pass a unittest baseline and reject both output-removal mutants. The Flask
check validates a constrained AST; this is not a deployed Flask server test.
Anthropic's 120-second profile default is explicitly capped to ten seconds for
the smoke, so the result does not claim its stock default is ten seconds.

The initial weaker Anthropic smoke pass is excluded from closure evidence.
The strengthened shell checker now permits equivalent actual Python invocations
without accepting echo/comment substitutes. Final strengthened smoke report
`evidence/coding-conformance-1790549433394.edn` records Anthropic passing creation,
editing, shell execution, truncation and steering. The subagent step then hit
`quota-exceeded`; the timeout step could not run because the session was closed.
This is five of seven steps, not a smoke pass. Anthropic is not being retried
against that quota limit. The same final report records **Gemini passing all
seven strengthened smoke steps**. Its observed Python command also satisfies
the final shell-invocation checker.

Final deterministic named audit: **261 tests / 2529 assertions, zero failures
or errors**, exit 0 (`/tmp/attractor-prepush-coding-audit-20260927.log`). It includes
the new live-conformance and smoke proof namespaces. The earlier full-suite
1566/14159/0 result predates this follow-up; publication verification is separate.

All three model families now have fifteen-row live coverage across the recorded
runs: first-party Anthropic and Gemini, and OpenAI through OpenRouter Responses.
All three model families also have seven-step smoke passes: first-party Gemini,
OpenRouter Responses/OpenAI, and OpenRouter Messages/Anthropic. This is not
45 first-party live cells or three first-party smoke passes: direct Anthropic
smoke stopped at quota exhaustion. First-party OpenAI wire evidence remains
accepted, and the user-requested gateway run supplies additional live proof. Generated
reports are local evidence; reproducible test/runner source belongs in Git.

## Default Model Selection Audit

# Omitted model selection

Unified LLM spec section 2.9 requires preferring the latest available model when
the caller omits one. The catalog had current entries, but client dispatch left
the model unset. Completion and streaming now resolve an omitted or nil model
after middleware selects the final provider. The order is explicit request,
adapter `:options :model`, then the provider's latest catalog entry.

Selecting at terminal dispatch avoids assigning an OpenAI default before
middleware reroutes to Anthropic. Explicit native model strings remain intact.
A custom provider without a configured model or catalog entry retains its
adapter's existing behavior; protocol compatibility alone does not establish
that an endpoint serves a first-party model ID.

`default_model_contract_test.lg` verifies requests received by adapters for all
three catalog providers, missing and nil fields, both client operations,
middleware rerouting, configured defaults, explicit models, and unknown providers.
Before repair: 18 failed assertions and no errors. After repair: 4 tests,
24 assertions, zero failures. Middleware routing (7/22), LLM (83/496), and build
also pass. Log: `/tmp/attractor-default-model-checks.log`.

This proves client dispatch behavior. It does not prove account access, live
provider support for each catalog entry, or automatic selection for custom
gateway names. The implementation still relies on the catalog freshness audit.

Integrated verification: `make test` exited 0 with 1137 tests, 10242 assertions,
and zero failures. Log: `/tmp/attractor-current-integration-suite.log`.
This run includes the current Anthropic request changes, default-model selection,
and preceding provider-error, Retry-After, and schema repairs. The preceding run
found five catalog-refresh integration failures: an obsolete latest-model test
expectation and four source-table column mismatches. The expectation now reflects
the refreshed catalog; the source table again places the cutoff second, retaining
its source links and the existing provenance checks.

---

## Middleware Routing Audit

# Middleware routing audit

Unified LLM sections 2.2 and 2.3 require dispatch by the request's provider and
allow middleware to modify requests. The client previously captured its adapter
before running middleware. Replacing `:provider` changed the request delivered
to that adapter but did not change which adapter executed it. An unknown
replacement provider could therefore reach an unrelated adapter silently.

Completion and streaming now select and validate the final provider at the
terminal middleware call. Streaming support is checked on that final adapter,
so middleware can redirect a request from a completion-only adapter to one
that supports streaming. Middleware still receives the initially normalized
request; registered model-prefix stripping runs only once, preserving native
model identifiers containing slashes.

`middleware_routing_contract_test.lg` verifies the selected adapter, normalized
provider, intact model, rejection of unknown replacement providers, and
streaming capability after rerouting. Five assertions failed before the fix;
four tests/six assertions pass afterward. Existing LLM tests (83/495), provider
tests (12/107), and the build pass. These checks cover client dispatch, not
automatic escalation policy or a live cross-provider retry journey.

## High-level streaming error attribution

The next audit reproduced stale provider attribution in `stream`: middleware
redirected local requests to a frontier adapter, but untyped provider errors and
synthesized missing-finish errors named the original local provider. High-level
event normalization now also wraps the final adapter's stream inside dispatch,
where the selected provider is known. The outer terminal guard remains for
middleware-produced or truncated streams. The public low-level `client-stream`
continues to return its raw middleware event sequence.

Two provider-attribution assertions failed before the repair. The test verifies
delivered frontier text, a single terminal error, its provider, and its category
for both explicit rate-limit errors and missing-finish streams. Middleware tests
now pass 5 tests/14 assertions; LLM tests pass 83/496, and the build passes.
Log: `/tmp/attractor-stream-routing-checks.log`. This covers adapter event errors;
it does not establish every transport exception's attribution or a live fallback
journey. The full-suite result of 1106/10046 predates this change.

## Rerouted transport failures and configuration retries

A scripted frontier adapter now verifies both sides of the stream retry boundary:
a socket failure before delivery is retried and yields the recovered response;
a socket failure after original text is delivered produces one terminal network
error without replacing the text with the scripted recovery. Both checks passed
without production changes. Network errors remain distinct from ProviderError;
the provider-field requirement in unified spec section 6.2 applies to the latter.

The audit then reproduced configuration errors being retried: routing to an
unregistered provider lacked `retryable: false`, so the retry default treated it
as transient. The regression makes an attempted retry raise a distinct error;
it checks the original configuration category and non-retryable flag survive.
Two assertions failed before repair. Client routing now marks absent, unknown,
and invalid default providers, plus missing streaming support, non-retryable.
Other adapter configuration-error construction sites still need assessment.

Middleware tests pass 7 tests/22 assertions; LLM tests pass 83/496, and build and
whitespace checks pass. Log: `/tmp/attractor-routing-retry-checks.log`. No new
full-suite run or live fallback journey is claimed.

## Remaining adapter configuration errors

The follow-up found the same missing flag in invalid adapter construction,
unsupported completion protocols, and unsupported streaming protocols. All
explicit configuration-error construction sites in `llm.lg` now carry
`retryable: false`, including the older provider dispatch helpers. This aligns
with unified spec section 6.3; callers can still explicitly override retry policy.

`configuration_error_contract_test.lg` verifies invalid adapter construction,
unsupported mock streaming through high-level retry handling, and unsupported
protocol errors for both adapter operations. Five assertions failed before the
repair. The final namespace passes 3 tests/13 assertions; middleware tests pass
7/22, LLM tests pass 83/496, and build and whitespace checks pass. The unsupported
protocol fixture supplies inert credentials and never reaches HTTP transport.
The broader suite has not been rerun for this change; configuration errors from
other modules or user-supplied adapters are outside this source-site audit.

---

## Model Catalog Sources

# Model catalog sources

`src/attractor/models.lg` records a `:knowledge_cutoff` only where the vendor
publishes one. Values are the vendor's *reliable* cutoff where two dates are
given. Anything not listed here is reported as `unknown` in the system
prompt's environment context. Verified 2026-09-10.

| Model | Cutoff | Source |
|---|---|---|
| claude-opus-4-6 | 2025-05 (reliable; training data to 2025-08) | https://platform.claude.com/docs/en/models/opus-4-6/overview |
| claude-haiku-4-5 | 2025-02 (reliable; training data to 2025-07) | https://platform.claude.com/docs/en/about-claude/models/overview |
| gpt-5.2 | 2025-08-31 | https://developers.openai.com/api/docs/models/gpt-5.2 |
| gpt-5.2-codex | 2025-08-31 | https://developers.openai.com/api/docs/models/gpt-5.2-codex |
| gpt-5-mini | 2024-05-31 | https://developers.openai.com/api/docs/models/gpt-5-mini |

Not recorded:

- claude-sonnet-4-5: the current models overview no longer lists a cutoff for
  this id (it is a legacy entry); left unknown until the dedicated page is
  checked.
- gpt-5.2-mini: removed on 2026-09-12; retaining an undocumented model as a
  catalog alias target conflicts with the catalog's purpose of supplying valid
  model identifiers. `gpt-mini` now identifies the documented `gpt-5-mini`.
- gemini-3.1-pro-preview, gemini-3-flash-preview: the Gemini API model pages
  publish a "latest update" date, not a training cutoff.

## Context limits corrected 2026-09-12

The linked official pages for GPT-5.2, GPT-5.2-Codex and GPT-5 Mini each
document a 400,000-token context window and 128,000-token maximum output.
The catalog previously assigned 1,047,576-token windows to all three OpenAI
entries. These values are now corrected to the published limits. Unknown
model IDs still pass through requests unchanged; catalog removal is not an
API allowlist restriction.

This correction verifies these specific entries. It does not establish that
the entire catalog is current or that its best-first ordering includes the
latest available models; that broader section 8.1 audit remains open.

## Current general-purpose entries added 2026-09-12

| Model | Reliable cutoff | Context | Maximum output | Source |
| --- | --- | ---: | ---: | --- |
| claude-fable-5-1 | 2026-06 | 1,000,000 | 128,000 | [Anthropic overview](https://platform.claude.com/docs/en/models/overview) |
| claude-opus-5 | 2026-05 | 1,000,000 | 128,000 | [Anthropic overview](https://platform.claude.com/docs/en/models/overview) |
| claude-sonnet-5 | 2026-01 | 1,000,000 | 128,000 | [Anthropic overview](https://platform.claude.com/docs/en/models/overview) |
| gpt-6-astra | 2026-04-30 | 1,050,000 | 128,000 | [OpenAI model page](https://developers.openai.com/api/docs/models/gpt-6-astra) |
| gemini-3.8-flash | Unknown | 1,048,576 | 65,536 | [Google model page](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash) |

These entries advertise tool, vision, and reasoning support. Current entries
precede retained older entries, so `get-latest-model` selects Fable 5.1, Astra,
and Gemini 3.8 Flash for their respective providers. This is advisory ordering,
not a claim of benchmark superiority or account access. Existing aliases keep
their prior targets; `fable` and `astra` are new aliases. Explicit model IDs
continue to pass through without requiring catalog membership.

Catalog presence is not integration proof. [Fable 5.1's documentation](https://platform.claude.com/docs/en/models/fable-5-1/overview)
requires adaptive thinking and rejects forced tool use; request-fixture coverage
for those behaviors is now recorded in `anthropic-modern-model-audit.md`.
Google's page likewise lists specific
thinking levels. Older retained entries still require a complete limit and
deprecation audit. LLM tests (83/496), context-capacity tests (16/77), and build
pass; no live model calls or full-suite run were made for this refresh.

Omitted-model dispatch is now covered separately in `default-model-audit.md`:
the final provider selects the catalog default after middleware, while explicit
and adapter-configured models take precedence.

---

## Session Prompt Model Metadata

# Session prompt model metadata

Coding-agent spec section 6.3 requires model display name and knowledge cutoff
in the environment block. The previous implementation omitted cutoff entirely
and rendered the raw model ID. Model routing itself was correct.

The session now snapshots optional trusted profile `:display_name` and
`:knowledge_cutoff`. Nonblank strings override advisory catalog fields of the
same name. Catalog fallback is allowed only when its provider matches the active
profile, including when looking up an alias. Unavailable display names fall back
to the actual model ID; unavailable cutoff is rendered explicitly as `unknown`.
Neither raw snapshot `:model` nor request `:model` is changed by these labels.

These are profile metadata, not prompt-derived/model-generated configuration.
For example, a custom profile may carry `:display_name "Local Model"` and a
verified `:knowledge_cutoff` string. No remote lookup occurs at session creation.
The existing catalog has no verified cutoff fields: the new fallback is honest
missing-data behavior, not proof of complete provider catalog metadata. Adding
real cutoff dates requires sourced catalog work; do not infer dates from names.

## Mechanical evidence

`test/attractor/prompt_metadata_test.lg` captures actual two-turn session requests
with controlled environment inspection and completion. It checks git branch,
changed-file count, recent messages, platform/OS/date, stable snapshots, profile
override/catalog/alias/provider-mismatch cases, blank/nonstring fallback, unchanged
request model IDs and final user override. Synthetic cutoff dates are fixture
data only. All sessions close in finally; no model credentials are needed.

Run: `/Users/ndn/development/let-go/lg -source-paths src:test test/runner.lg attractor.prompt-metadata-test`.

- RED: 3 tests / 26 passing / 40 failing assertions / zero errors.
- Native GREEN and outside-checkout bundle: each 3 tests / 66 assertions /
  zero failures or errors. CLI build/help also passed.
- Actual Claude implemented the single production-file change through the
  framework connector. Main owns tests, source inspection and verification.
- Full default suite: 722 tests / 6,992 assertions / zero failures, exit 0.
  Independent bounded Claude spec/correctness review approved the change.

This fixes the two prompt metadata defects. Complete catalog facts and full
Attractor/provider conformance remain separate obligations.

---

## Provider Error Audit

# Provider error audit

The pinned unified LLM spec sections 6.2–6.4 require portable error fields,
retryability, and HTTP status mappings. `provider_error_contract_test.lg` checks
400, 401, 403, 404, 408, 413, 422, 429, and representative server-range codes
(500, 504, 505, 599) against the prescribed category, retryability, status, and
provider. These cases passed without production changes.

The Anthropic completion fixture reproduced a missing normalized `error_code`:
the response's `error.type` remained in `raw` but was not exposed as the native
error identifier. `provider-error` now falls back to the error payload's `type`
when no explicit `code` exists. An envelope's generic top-level type does not
override its nested error payload. Explicit codes retain precedence.

One assertion failed before the fix. Provider-error tests pass 3 tests/17
assertions, LLM tests pass 83/496, and build and whitespace checks pass.
Log: `/tmp/attractor-provider-error-checks.log`. This is transport-fixture
evidence, not a live rate-limit journey. Message/status conflicts, the complete
gRPC table, and HTTP-date Retry-After values remain outside this audit's evidence.
The integrated 1106-test suite result predates this change.

## Native gRPC status precedence

The full eight-status table from unified spec section 6.4 now has fixture
coverage with an HTTP 400 envelope. Four cases failed before the repair:
RESOURCE_EXHAUSTED, UNAVAILABLE, DEADLINE_EXCEEDED, and INTERNAL were incorrectly
classified as invalid requests because HTTP conditions ran before those native
status checks. Recognized gRPC statuses now use a single category mapping before
HTTP fallback. The actual HTTP status remains 400 in error metadata. Unknown
native statuses still fall back to the HTTP code.

Existing context, content-filter, and billing/quota refinements remain earlier
in classification; this change does not settle all message/status conflicts.
Provider-error tests pass 5 tests/26 assertions after four assertions failed
before the repair. LLM tests pass 83/496, and build and whitespace checks pass.
Log: `/tmp/attractor-grpc-error-checks.log`. This is classification evidence, not
a live native-Gemini retry journey. Full-suite verification predates the repair.

## Retry-After header casing

Header lookup previously recognized only conventional and lowercase spellings.
It now handles arbitrary case for string and keyword header keys, consistent with
[HTTP field-name semantics](https://www.rfc-editor.org/rfc/rfc9110.html#section-5.1).
The regression feeds a 90-second delay through the retry utility with a
60-second maximum and makes any retry callback raise a distinct failure. This
proves differently cased headers preserve the original rate-limit error and its
delay instead of silently entering backoff.

Eight assertions failed before the repair. Retry-After tests pass 1 test/16
assertions; provider-error tests pass 5/26, LLM tests pass 83/496, and build and
whitespace checks pass. Log: `/tmp/attractor-retry-after-checks.log`.
HTTP-date values remain unimplemented: parsing currently accepts numeric delays
only. Numeric validity (negative and non-finite values) also needs assessment.

## HTTP-date Retry-After values

The numeric-only limitation above is now partially closed: standard IMF-fixdate,
RFC 850, and asctime-shaped dates are recognized and converted to seconds until
the timestamp; elapsed dates become zero. Date components are checked by let-go's
ISO instant reader, then converted with Gregorian calendar arithmetic. The
runtime's `inst-ms` accepts boxed `(now)` values but does not accept its parsed
`#inst` values, so parsing and epoch conversion cannot simply share that helper.

Five date assertions failed before the repair. Retry-After tests now pass
4 tests/27 assertions, including impossible calendar dates, future and elapsed
dates, and an actual retry-policy check that a distant date preserves the original
error without retrying. Provider-error tests (5/26), LLM tests (83/496), build,
and whitespace checks pass. Log: `/tmp/attractor-http-date-checks.log`.

This is not complete HTTP-date conformance: the RFC 850 century adjustment is
currently year-based, so the exact 50-year boundary still needs refinement.
Leap seconds, weekday/date consistency, numeric negative/non-finite values,
and full-suite verification also remain outside this evidence.

## Invalid numeric delays

Negative and non-finite numeric Retry-After values were accepted by `parse-double`.
Negative values and NaN reached the wait function; positive infinity instead
suppressed retries by exceeding the maximum delay. Parsed numeric delays now
must be nonnegative and finite. Invalid values leave `retry_after` unset so the
normal retry policy supplies backoff. Zero, whitespace-trimmed numbers, and the
existing fractional-second extension remain supported.

The regression observes the actual backoff passed to the wait callback for
negative values, NaN, both infinity spellings, overflow, and malformed text.
Twelve assertions failed before the repair. Retry-After tests pass 6 tests/51
assertions; provider-error tests pass 5/26, LLM tests pass 83/496, and build passes.
Log: `/tmp/attractor-numeric-retry-after-checks.log`. This validates incoming
headers; arbitrary invalid numbers supplied directly in user retry-policy maps
are outside this evidence.

Integrated verification after the reference, middleware, error-classification,
configuration-retry, and Retry-After changes: `make test` exited 0 with 1125 tests,
10167 assertions, and zero failures. Log: `/tmp/attractor-shared-transport-suite.log`.
This supersedes the earlier regression totals, while the explicit conformance
limitations in this audit remain open.

## Legacy-date fifty-year boundary

The year-only limitation is now repaired for Retry-After delay calculation.
The parser normalizes the current clock to UTC and compares the target against
the complete timestamp fifty calendar years ahead. A legacy date beyond that
boundary denotes the prior century and therefore produces zero delay. Equality
at the boundary remains future, as required by the rule's strict "more than".

A fixed-clock test checks one second before, exactly at, one second after, and
one day after the boundary. Two assertions failed before the fix. Retry-After
tests pass 7/55, provider-error tests pass 5/26, LLM tests pass 83/496, and build
and whitespace checks pass. Log: `/tmp/attractor-http-date-boundary-checks.log`.
The integrated 1125/10167 result predates this repair. Leap-second support and
weekday/date consistency remain unverified.

## Leap-second spelling

HTTP-date permits `23:59:60` ([RFC 9110 section 5.6.7](https://www.rfc-editor.org/rfc/rfc9110.html#section-5.6.7)),
but the runtime's ISO parser rejected it. Calendar validation now substitutes
the preceding second for that specific spelling, while epoch arithmetic retains
the extra second. This uses the system's POSIX clock representation; it does not
introduce a leap-second table or alter clock synchronization.

A fixed-clock test at 2016-12-31 23:59:58 UTC verifies a two-second delay for
all three HTTP-date formats and rejection of `23:59:61`. Three assertions failed
before repair. Retry-After tests pass 8/59, provider-error tests pass 5/26, LLM
tests pass 83/496, and build and whitespace checks pass.
Log: `/tmp/attractor-leap-second-checks.log`. Full-suite verification predates
this repair; weekday/date consistency remains outside the evidence.

## Outage messages retain server retryability

Message heuristics previously converted explicit server failures into permanent
client failures when their text mentioned safety, billing, missing deployments,
or invalid cache keys. Unified spec sections 6.4–6.5 classify server statuses as
retryable and reserve message heuristics for ambiguous cases. Explicit native
server status now wins over message heuristics; absent a recognized native
status, HTTP 500–599 also wins. A recognized non-server native status continues
to take precedence over the HTTP envelope.

Six assertions failed before the repair. Tests cover HTTP 503 and native
UNAVAILABLE with misleading service names, plus retained context, safety-policy,
and billing refinements for HTTP 400. Provider-error tests pass 7/37, LLM tests
pass 83/496, and build and whitespace checks pass.
Log: `/tmp/attractor-server-error-checks.log`. Other client-status/message
conflicts and a new full-suite run remain outside this evidence.

---

## Provider Reference Alignment Gap

### Local contract and reference provenance — 2026-09-29

CAL-PROFILE-01 uses behavioral alignment as explicitly described by Appendix C
and §6.2 of the checked-in coding-loop spec. §3.1's byte-for-byte reference-base
wording conflicts with those sections; literal reference-asset equivalence
remains unproved and is not our implementation contract.

Profiles use locally authored prompts and schemas in `profiles.lg`, with native
editing formats and provider-specific affordances. No extracted vendor prompt,
reference commit, or rendering configuration is claimed. Registry, prompt-topic,
execution, wire, and live parity tests establish their named behaviors, not
complete equivalence to the reference agents. Shared host executors are allowed
under Appendix C's adaptation rationale.

The [coding-loop follow-up](coding-loop-audit-2026-09-27.md#provider-alignment--explicit-precedence-and-provenance)
records this precedence decision. A future exact-reference compatibility mode
would require separately pinned, available source assets and comparison tests;
it is not silently inferred from passing model calls.

---

## Anthropic Modern Model Audit

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

---

## Gemini Provider Aliases

# Gemini provider aliases

Provider registry IDs are application names; the configured protocol determines
adapter behavior. A Gemini endpoint registered under a custom ID must preserve
tool-call state just as the built-in `gemini` provider does.

The 2026-09-12 audit found `make-provider-adapter` creating its call-ID/name
lookup only when the ID was literally `gemini`. Responses were otherwise
decoded correctly through the configured native protocol, but a subsequent
tool result carrying only `tool_call_id` serialized as a Gemini
`functionResponse` with an empty name.

The lookup is now allocated per adapter whenever its protocol is
`:gemini-generate-content`. The regression drives a custom provider through
the real complete and streaming decoders, then sends the resulting call ID back
without repeating the tool name. It inspects the serialized native continuation
and checks the recovered name, result content and final reply. Both paths failed
the name assertion before the fix and now pass.

Verification: alias contract 1 test/8 assertions; LLM 83/495; providers 12/107;
all passing, with a successful CLI build. The test supplies an in-memory
transport and protocol lookup to isolate this adapter behavior. It does not
establish a credentialed Gemini server run; that live matrix remains pending.

---


## Unified Core Infrastructure Audit

# Unified core infrastructure audit

This maps each Unified LLM section 8.1 checkbox to inspected source and tests.
It distinguishes component coverage from outstanding proof instead of relying
on the historical ULLM-CORE-01 completion label.

| Requirement | Inspected evidence | Assessment |
| --- | --- | --- |
| Client from environment | `llm/client-from-env`; `test-client-from-env-registers-only-configured-providers` checks OpenAI/Google keys and default selection | Component coverage; this fixture does not independently prove every environment alias |
| Explicit adapters | `make-client`; `test-client-initializes-and-closes-adapters`, routing tests | Component coverage |
| Explicit provider routing | `client-provider`, terminal middleware dispatch; `test-client-routes-default-and-explicit-providers`, `middleware_routing_contract_test.lg` | Component coverage, including changed and unknown middleware destinations |
| Default provider | Same routing test checks adapter and model received without an explicit provider | Component coverage |
| Configuration error without provider/default | `routed-request` raises `:configuration`; existing routing test only checks that an exception occurs | Source supports it; strengthen the error-category assertion |
| Middleware onion order | `llm_contract_test.lg` checks three middleware request/response phases; streaming observer tests inspect transformed events | Component coverage; later routing regression is recorded separately |
| Module default and lazy initialization | `module-default-client-lifecycle` plus `default_client_contract_test.lg` verify explicit/default use, lazy reuse, and an explicit setter racing initialization | Component coverage; publication race fixed |
| Current model catalog and lookups | `models.lg`, lookup tests, `model-catalog-sources.md`, `default_model_contract_test.lg` | Current general-purpose entries added; omitted models now resolve after middleware, with explicit/configured models taking precedence. Older-entry freshness and live compatibility remain partial; see `default-model-audit.md` and `anthropic-modern-model-audit.md` |

The module-default race is now reproduced and fixed. The former
`get-default-client` read the atom, constructed a client, and unconditionally
reset it. A promise-coordinated regression pauses construction, installs an
explicit client, and releases construction. Before the fix, four assertions
failed: the waiting caller and subsequent generation used the environment
client, and the discarded candidate was not closed.

Publication now uses compare-and-set from nil. A losing initializer closes
its unpublished candidate and reads the installed client again. Sequential
reuse is also verified by making a second environment construction throw and
successfully generating through the existing default. Tests preserve and
restore the global default. The new namespace passes two tests/seven assertions;
LLM contract tests (21/76), LLM tests (83/495), and build pass. This is not a
proof of every possible concurrent setter/reset interleaving.

Source inspection also confirms the application extension that registered
`provider/model` prefixes select a provider. The upstream spec describes native
model strings and explicit/default providers; this extension must remain
documented as an application convention, rather than being mistaken for an
upstream requirement.

Integrated verification after the middleware-routing, tool-choice, catalog,
and provider-evidence changes: `make test` exited 0 with 1084 tests, 9919
assertions, and zero failures. Log: `/tmp/attractor-shared-transport-suite.log`.
That integrated run predates the default-client fix. It does not establish
catalog freshness; the fix has the focused verification recorded above.


## Unified Provider Evidence Audit

# Unified provider evidence audit

Audited 2026-09-12 against unified-llm-spec §§8.6, 8.9 and the retained
`evidence/provider-matrix-evidence.edn`. Historical records are preserved as observations;
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
| Base64 image | Spatial color check and exact wire payload pass through Messages/Opus 4.6 and Responses/GPT-5.2 gateways. Earlier GPT-4.1 mini failures remain retained; Gemini native pending. |
| URL image | Exact URL serialization and subject/color answers pass through Responses and Messages gateways; Gemini native pending |
| Single tool plus execution | Checks execution and incorporation of supplied result |
| Multiple parallel tools | Passes locally and through Responses/Messages gateway endpoints; Gemini native pending |
| Three or more tool rounds | Passes locally and through Responses/Messages gateway endpoints; Gemini native pending |
| Streaming tools | Passes locally and through Responses/Messages gateway endpoints; Gemini native pending |
| Structured output | Checks required city/country string values |
| Reasoning-token reporting | Responses GPT-5.2 gateway passes. Messages/Opus 4.6 reports a positive estimate and correct residue but fails the requested final-answer format; Haiku's earlier arithmetic failure remains retained. Gemini native pending. |
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

`evidence/provider-url-image-evidence.edn` records two live passes: Messages/Claude
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

Fresh gateway results are retained in `evidence/provider-image-content-evidence.edn`:
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

`evidence/provider-image-wire-evidence.edn` retains the live result: both Responses and
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
retained result (local output: `evidence/provider-multi-round-local-evidence.edn`). This establishes the
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
retained result (local output: `evidence/provider-parallel-local-evidence.edn`). Regression checks prove
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
retained result (local output: `evidence/provider-streaming-tools-local-evidence.edn`), including the
ordered event types, tool-end/step-finish positions and returned opaque value.
Combined verifier checks pass 5 tests/26 assertions. As with the other new
journeys, this establishes the local Chat Completions path; native-provider
cells and the remaining image, caching, usage and options rows stay open.

## Responses and Messages tool journeys

Fresh verification runs all three new tool journeys through both native
protocol adapters against OpenRouter's compatible endpoints. All six pass,
with no skips: retained results (local output: `evidence/provider-tool-protocol-evidence.edn`).
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
retained result (local output: `evidence/provider-reasoning-responses-evidence.edn`). This is direct
evidence of the native Responses usage field being exposed through the client.

Messages gateway verification on Haiku 4.5 reports an estimated 678 reasoning
tokens, but returns the incorrect residue 385, so the complete journey remains
failed: diagnostic result (local output: `evidence/provider-reasoning-messages-evidence.edn`). The SDK
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
retained wire options (local output: `evidence/provider-options-protocol-evidence.edn`). Responses uses
`metadata.audit_token`; Messages uses the native `metadata.user_id` field with
a synthetic UUID, not a person's identifier. The implemented Gemini journey
uses a native safety-settings option but still lacks a credentialed live run.
This proves option transmission and request acceptance, not undocumented
server-side effects of metadata. Existing adapter tests separately cover
portable-setting overrides and beta headers. Combined verifier checks pass
8 tests/43 assertions.

## Stronger-model follow-up

The existing image and reasoning predicates were rerun without relaxing them.
`evidence/provider-capable-image-followup.edn` records base64-image passes for both
`or-responses/openai/gpt-5.2` and `or-messages/anthropic/claude-opus-4.6`.
Both serialized image payloads match the fixture and both answers are
`red, blue`. This supplies successful live evidence for each native adapter's
image path through the gateway while preserving the earlier Mini failures.

`evidence/provider-capable-model-followup.edn` contains reasoning-only results:
GPT-5.2 passes with 1172 reported reasoning tokens. Opus 4.6 returns the correct
residue 353 and an estimated 296 reasoning tokens, but also supplies an
explanation despite the requested final-integer-only response. The strict
journey therefore remains failed under its existing `incorrect-reasoning-answer`
category; the retained text demonstrates a format violation, not wrong arithmetic.
No hidden thinking blocks are retained in the report.

A direct Anthropic preflight using the configured `claude-gw` alias reaches
`api.anthropic.com` and fails with the low-credit-balance response, classified as
`quota-exceeded`: `evidence/provider-direct-anthropic-preflight.edn`. The sandbox DNS
failure was followed by this network-authorized check. Direct first-party
completion is still not established. OpenAI and Gemini built-ins have no
configured credentials in this environment.

## Reject misspelled journey selections

The runner silently ignored unknown names in `ATTRACTOR_MATRIX_JOURNEYS`.
For example, `image,reasoning` executed only reasoning because the image journey
is named `image-base64`. A mixed selection could therefore report successful
execution without running everything the caller requested.

Configured-provider runs now reject unknown names before executing a journey or
writing a report, listing the available names. The selection helper preserves
declared order and action functions; nil selects all, and an empty set selects
none. Verifier tests pass 14 tests/85 assertions, including mixed valid/invalid
selection. An actual runner invocation with `image,reasoning` exits 1 with the
unknown-name diagnostic and creates no evidence file. Log:
`/tmp/attractor-invalid-journey-check.log`. The previous 1145-test integrated
result predates this focused runner change.

Reproduce the retained successful image rows using the credential-free
`test/live/openrouter_protocols.edn` overlay, provider filter
`or-responses,or-messages`, model overrides `openai/gpt-5.2` and
`anthropic/claude-opus-4.6`, and journey filter `image-base64`. Reasoning is a
separate `reasoning` selection. Keep separate evidence paths so later runs do
not overwrite earlier failures. Native Gemini, first-party completion, live
rate limiting, and the other open release requirements remain unproved.

## Bounded model-catalog refresh — 2026-09-23

Rechecked the catalog entries below against their official provider pages.
`src/attractor/models.lg` now corrects Opus 4.6's context window, adds the
current Opus and GPT-6 Sol/Luna entries, and records Sonnet 4.5's published
reliable cutoff. Cutoff values retain a source URL in the catalog.

| Model | Reliable cutoff | Context | Maximum output | Official source |
| --- | --- | ---: | ---: | --- |
| claude-opus-4-6 | 2025-05 | 1,000,000 | 128,000 | [Anthropic Opus 4.6](https://platform.claude.com/docs/en/models/opus-4-6/overview) |
| claude-opus-5-5 | 2026-06 | 1,000,000 | 128,000 | [Anthropic Opus 5.5](https://platform.claude.com/docs/en/models/opus-5-5/overview) |
| claude-sonnet-4-5 | 2025-01 | 200,000 | 64,000 | [Anthropic Sonnet 4.5](https://platform.claude.com/docs/en/models/sonnet-4-5/overview) |
| gpt-6-sol | 2026-04-20 | 1,050,000 | 128,000 | [OpenAI GPT-6 Sol](https://developers.openai.com/api/docs/models/gpt-6-sol) |
| gpt-6-luna | 2026-05-18 | 1,050,000 | 128,000 | [OpenAI GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna) |

Opus 5.5 is listed after Fable 5.1 and before Opus 5, leaving Fable first for
the quality-oriented default. GPT-6 Sol and Luna follow Astra and precede the
retained older OpenAI entries. Existing aliases still resolve to their prior
model IDs. Opus 5.5 uses the existing Anthropic capability metadata to require
adaptive thinking and reject forced tool choice before transport.

The linked pages also document tool calls, image input and reasoning for all
three newly added current models. These deterministic catalog and request
capture checks establish metadata and serialization behavior only; they do not
establish live account access or model availability for any credential.

Implemented by gpt-6-luna. Root verification across Anthropic model contracts,
LLM contracts, client defaults, prompt metadata and context capacity passes
137 tests / 822 assertions / zero failures/errors. Paired spec and quality
reviewers approve; each quality reviewer independently ran the three changed
namespaces (16/169/0). Final `lgx test` on 0.3.2 passes **1485 tests / 13406
assertions / zero failures**, exit 0. Logs:
`/tmp/attractor-catalog-focused-20260923.log` and
`/tmp/attractor-catalog-integrated-20260923.log`. A fresh standalone CLI
validates `examples/hello.dot` with no diagnostics.

The current source-namespace catalog packaging predates this bounded repair.
The §2.9 preference for a separately updateable offline data artifact remains
tracked in the final specification audit; this does not authorize a downloaded
catalog layered into provider/auth configuration.

## Funded native provider journeys — 2026-09-24

After the user funded AI Studio and Anthropic, root invoked the shared
`live.provider-matrix-journeys` functions with each native adapter and a
transport observer that records status and signed-history counts, never keys
or headers. The local wrapper loads `.env` before using the existing provider
credential resolver; structured EDN credentials remain supported independently.

| Native model | Selection | Verified subset | Remaining condition |
| --- | --- | --- | --- |
| Gemini 3.1 Flash Lite | explicit override | Eight rows: text, stream, exact Alice/30 extraction, streaming tools, parallel tools, multi-round tools, agent loop, nonexistent-model404 | The one rate-limit request returned200;429 is unproved and aggregate is incomplete |
| Claude Haiku 4.5 | explicit override | Same eight rows | The one rate-limit request returned200;429 is unproved and aggregate is incomplete |
| Gemini 3.8 Flash | actual catalog default | Text, parallel tools and agent loop | Other default-model rows were not selected |
| Claude Fable 5.1 | actual catalog default | Text, parallel tools and agent loop | Other default-model rows were not selected |

Gemini continuation requests carried the returned opaque signatures; sequential
tool steps retained one, then two, then three signed parts. The Anthropic
ordinary runs did not return thinking blocks, so they do not establish that
specific behavior. A separate real Fable 5.1 agent session with high reasoning
effort executed one lookup and replayed a returned thinking block; both native
requests returned200 and the final answer contained the tool's opaque value.
No thought text or signatures are retained in this trace, only block counts.

Local evidence files are under ignored `evidence/`:
`native-provider-journeys-20260924-{gemini,anthropic}-{low-cost,catalog}.edn`
and `native-provider-journeys-20260924-anthropic-thinking.edn`.
The local reproduction driver is
`/tmp/attractor-native-provider-journeys-20260924.lg`; the normal reusable live
entry point remains `make live-matrix` with provider/model/journey selectors.
These are bounded native subsets, not full provider or coding-agent parity.
Native OpenAI credentials, native429 evidence, the remaining matrix rows and
the full shared-session smoke remain open. No auth or billing configuration
was changed by these checks.

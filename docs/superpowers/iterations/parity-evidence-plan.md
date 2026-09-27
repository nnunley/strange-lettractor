# Remaining parity and smoke evidence

Original requirements: coding-agent §§9.12–9.13 and unified-LLM §§8.9–8.10.
The live agent runner offers all fifteen rows. Both bounded runner batches are
reviewed and integrated: ITER-0020 agent journeys, then ITER-0021 provider
journeys and signed-history repair. Final suite1526/13863/0; focused62/673/0.
The sections below retain the approved contracts; the shared-session smoke
and full native matrices remain open. Use Sol for integration and Luna for
bounded predicate/data work. Keep implementation sequential. Scripted evidence
does not establish first-party results.

## Coding-agent runner

Extend `test/live/parity_matrix.lg` and shared evidence predicates with five
rows. Keep normal real sessions, native profiles, tools and temporary files.
Use row-specific session options and lifecycle hooks where a test requires a
mid-turn action; retain deterministic cleanup and bounded execution.

- **Parallel tool calls:** require multiple calls in one assistant turn,
  executor overlap, successful results and their real file effects. Merely
  seeing two start events is insufficient. Instrument the supplied environment
  if needed while still executing its real operations.
- **Steering mid-task:** inject once at an observed tool boundary; prove the
  next request receives the steering and the requested changed file outcome.
- **Reasoning change:** change effort at an observed boundary; prove subsequent
  request/serialized native options change, with a completed continuation.
- **Subagent spawn/wait:** enable depth one for this row; require actual spawn
  and wait calls with matching identity, child file effects and joined cleanup.
- **Loop warning:** drive repeated identical calls through the real session;
  prove the warning event and its injection into a subsequent model request.

Reuse the same proof predicates in deterministic native-adapter tests and live
runs. Verify failure controls so a row cannot pass from tool names, generic
nonempty text or intended setup alone. Cover all three native protocols; report
model capability and invocation errors separately from proven library behavior.

## Unified client and integration smoke

- Add the missing rate-limit row, requiring an actual observed HTTP 429 that
  normalizes to retryable rate limiting. Never label injected/local responses
  as native evidence or aggressively exhaust an account to obtain a 429.
  Bound any real requests, and report the cell unproved if the target does
  not produce rate limiting. Existing loopback retries remain component proof.
- Add nonexistent-model → NotFoundError smoke with no retries. Check the basic
  native generation journey's nonempty text, positive input/output counts and
  stop completion explicitly, not through an unrelated row's counts.
- Inventory every step of both integration smoke checklists against the runner
  and evidence; a complete row-name list does not establish a complete journey.

Native Gemini funding is restored as of 2026-09-24: after the user added $5,
one retry-disabled Gemini 3.1 Flash Lite request returned HTTP 200 and the
expected READY response (5 input / 2 output tokens). Evidence is retained in
`evidence/native-gemini-trace-20260924-funded.edn`. Anthropic basic native access
was also restored after user funding/configuration: Haiku 4.5 returned HTTP 200
and READY (12 input / 6 output tokens), recorded in
`evidence/native-anthropic-trace-20260924-funded.edn`. Only native OpenAI
credentials remain absent. ITER-0021 now fixes the signed-history dependencies
below. Eight selected native journeys pass on both low-cost providers; text,
parallel tools and agent loop also pass on both catalog defaults. A separate
Fable high-reasoning agent session proves signed-thinking replay. Each bounded
rate-limit request returned200 and remains unproved. See
`docs/provider-model-audits.md`; these subsets do not establish full matrix parity.

## Smoke checklist inventory (2026-09-23)

The table records what the current runners assert, independently of whether a
native run is available. Completing matrix rows alone leaves the shared-session
coding-agent journey unproved.

| Original smoke step | Existing runner evidence | Remaining runner work |
|---|---|---|
| Unified §8.10.1 basic generation | `provider_matrix.lg` text row checks a requested word and records usage/finish | Assert positive input/output tokens and stop completion on that same response |
| Unified §8.10.2 streaming | Stream row requires a text delta and a final answer containing `3` | Assert concatenated deltas equal the final response text |
| Unified §8.10.3 parallel tools | Parallel row executes two overlapping tools and verifies both returned values in the answer | Retain proof of both same-step results and continuation; expose the required minimum step count in the shared predicate |
| Unified §8.10.4 image | Base64 row checks serialized PNG and correct two-color answer | Existing runner assertion is adequate; native cells remain unproved |
| Unified §8.10.5 structured extraction | Structured row accepts any string-valued city/country | Add known-input extraction with exact expected name and age |
| Unified §8.10.6 missing model | No nonexistent-model journey | Add native NotFound normalization and observed single attempt |
| Coding-agent §9.13.1–3 creation/edit/shell | Matrix uses separate sessions for each row | Add one persistent real session that creates `hello.py`, preserves Hello while adding Goodbye, then executes it with successful tool/output evidence |
| Coding-agent §9.13.4 truncation | Matrix checks large raw output and model truncation marker in an independent session | Exercise the prescribed large file in the same smoke session and correlate event/result identities |
| Coding-agent §9.13.5 steering | Missing matrix row and shared-session step | Add observed-boundary steering plus changed implementation, in both reusable row and smoke journey |
| Coding-agent §9.13.6 subagent | Missing matrix row; all current row sessions disable children | Add spawn/wait with child result and shared-session continuation |
| Coding-agent §9.13.7 default timeout | Matrix explicitly requests 200 ms | Smoke must omit per-call timeout and prove the configured 10-second default is used, with timeout handling and continuation |
| Attractor §11.13.1–2 parse/validate | Deterministic `smoke_test.lg` checks goal, five nodes, six edges, validation; live runner uses public preparation/run gate | Carry explicit prepared-graph assertions into the retained live evidence |
| Attractor §11.13.3–4 execution/artifacts | Live pipeline checks successful path and nonempty response/status artifacts for all three stages | Preserve real backend proof and distinguish it from deterministic callback evidence |
| Attractor §11.13.5 goal gate | Live success traverses a declared goal gate, but does not directly record its satisfaction | Assert and retain the implementing node's successful recorded outcome as the gate evidence |
| Attractor §11.13.6 checkpoint | Live runner checks terminal node and exact completed set | Existing runner assertion is adequate |

Keep smoke sessions bounded and close them in `finally`, including failure
paths. Preserve diagnostic evidence while cleaning only temporary work roots.
New shared predicates need negative controls for missing deltas/results,
wrong extraction values, lost prior file content, and default-timeout overrides.

## Existing integration seams

`agent/set-reasoning-effort!` and `agent/steer-session!` are already public.
The tool boundary emits `:tool_call_start`/`:tool_call_end` with `:call_id`;
history tool results use `:tool_call_id`. Correlate those identities rather
than relying on event count/order alone. Loop warnings emit `:loop_detection`
and append a `:steering` turn; existing `agent_loop_contract_test.lg` proves
the warning reaches the subsequent request, with a disabled-warning control.

`agent_loop_wire_test.lg` already supplies three native protocol examples for
steering/history continuation and request capture. Its reasoning wire assertion
currently covers OpenAI specifically, so it does not by itself prove changed
native reasoning settings for all three families. `agent_subagent_wire_test.lg`
calls public spawn/wait functions directly; the new parity proof must exercise
the model-returned `spawn_agent` and `wait` tools through the parent loop.
Child events reach the parent as `:subagent_event` with `:agent_id` and nested
`:event`; retain these identities when checking the child's actual file work.

Keep any request observation in the harness's supplied transport/middleware.
No new production interception interface is needed. A row-specific environment
wrapper may observe or synchronize real operations, but must still delegate
them to the supplied local environment and assert the resulting file/tool effects.

Current executable scripts use namespace `main` and dispatch when
`*command-line-args*` is nonempty. Do not require such an executable from a test
and accidentally start a live run with the test runner's arguments. Keep reusable
journey execution/checking in an ordinary `live.*` test-support namespace and
the credential/env selection plus command dispatch in the executable wrapper.
Exercise that shared journey through the native recording server as well as
through live adapters; predicate-only tests cannot prove runner orchestration.

## Sequential implementation batches

Keep briefs bounded instead of assigning this entire document to one worker:

Priority update (2026-09-24): finish batches 1 and 2, then execute the approved
`../plans/2026-09-23-offline-model-catalog.md` extraction before batch 3.

1. **Agent parity journeys (gpt-6-sol):** factor the existing agent runner's
   reusable session/journey code, implement the five missing rows and shared
   evidence predicates, then exercise those exact journeys against the three
   scripted native protocols. Preserve the existing ten rows and CLI selection.
2. **Provider journeys (gpt-6-sol):** factor only the provider runner code
   needed for deterministic invocation; strengthen generation, streaming,
   parallel continuation and exact extraction checks; add missing-model and
   bounded rate-limit journeys. Exercise the shared runner, including failure
   controls. Native rate limiting remains unproved without an actual 429.
3. **Shared-session integration smoke (gpt-6-sol):** add the seven-step coding
   smoke using the established agent journey helpers, plus explicit prepared
   graph and goal-gate assertions in the Attractor live smoke. Test the same
   orchestration with scripted native responses and actual local tools.

Each batch retains focused executable scenarios and gets independent review
before the next implementer starts. Run the integrated suite and standalone
entry points on a settled final snapshot. Keep native-provider cells separate
from deterministic runner coverage; unavailable credentials or depleted credit
must not trigger repeated unchanged requests.

## Batch 1 scope-review proof contract — ITER-0020

The existing recording server emits a single tool call per response; extending
that fixture is part of batch 1. Add distinct per-row scenarios with native
multi-call completion/SSE frames and unique call IDs. Parent/child scripts must
route from the actual request history, and the scripted parent `wait` must take
its agent ID from the preceding observed spawn result. A provider-wide attempt
counter cannot safely represent the concurrent parent/child conversation.

For each of the three native protocols, tests must invoke the exact extracted
journey function that the live CLI invokes, with actual local tool operations.
The older independent wire matrix does not substitute for this shared runner.
The following checks and their failure controls are required:

- Parallel: a bounded barrier around delegated real environment operations
  proves overlap; one assistant history turn contains both calls, successful
  results correlate by call ID, and both resulting files are checked. Reject
  serial execution, unmatched/failed results or missing file effects.
- Steering: inject at an observed tool boundary, then make the fixture's next
  tool action depend on the steering text in the actual continuation request.
  Check the changed file and reject missing steering or the wrong file result.
- Reasoning: compare low-to-high changes in actual native serialized options
  for all three protocols, with completed continuation. Inspect the fields
  appropriate to the selected model (OpenAI effort, Anthropic adaptive effort
  or legacy budget, Gemini thinking level/budget). Reject unchanged settings.
- Subagents: model-issued spawn and wait appear in parent history, with the
  generated child ID matched across their results, forwarded child events and
  actual child file work. Verify joined/closed child state after parent cleanup.
  Avoid a child model override for alias-backed live profiles; the inherited
  native profile suffices. Reject direct-helper-only, mismatched identity or
  missing child work as proof of this journey.
- Loop warning: correlate repeated calls, the warning event, the steering
  history entry and its presence in the next model request. Include a disabled
  detection control; a warning event alone cannot pass.

Session closure belongs in `finally` for every row, including exceptional
paths. Capture proof and diagnostic values before removing temporary work
roots; verify cleanup without erasing retained evidence. Preserve the existing
ten rows, native profiles for aliases, and `ATTRACTOR_PARITY_ROWS` selection.
Predicate controls may supplement, but cannot replace, orchestration checks.
No production interception interface or provider/smoke batch work is required.

### Confirmed reasoning dependency — 2026-09-23

Batch-1 inspection found that `gemini-generation-config` emits `thinkingLevel`
for every model, including Gemini 2.5. Google's
[thinking guide](https://ai.google.dev/gemini-api/docs/generate-content/thinking)
requires `thinkingBudget` for 2.5; Pro accepts 128–32768, Flash 0–24576,
and Flash Lite 512–24576. The harness must not certify a 2.5 journey from
the fixture's willingness to accept an invalid native field.

The same gpt-6-sol implementer is authorized to repair this bounded dependency
in `llm.lg`, with failing serializer tests before the fix. For known 2.5 model
names (including the supported `models/` prefix), map portable low/medium/high
to 1024/8192/24576. This is the library's mapping policy within documented
ranges, not a vendor-prescribed equivalence. Preserve Gemini 3 and unknown-model
behavior, omission when effort is absent, and explicit provider-option overrides
(including string-key maps and native 0/-1 budgets). A portable mapping must
not leave both thinking fields in the final payload.

Verify actual completion and streaming request bodies, retain a Gemini 3
level-based regression, and run the shared low-to-high journey on Gemini 2.5
with budget evidence. This closes a CAL-REASON-01 / ULLM-QUIRKS-01 dependency
without introducing a production observation interface or expanding to live
provider access. Independent reviews and integrated verification must include
the adapter correction.

## Batch 2 adjacent runner findings — read-only audit, 2026-09-23

Carry these existing runner issues into the provider-journey batch, without
changing batch 1's scope:

- `provider_matrix.lg`'s `:agent-loop` row removes its directory without closing
  its session and has no `finally` around execution. Factor deterministic
  closure and temporary-root cleanup with the shared provider journeys, retaining
  diagnostic values before cleanup and covering failure paths.
- The prompt-cache row always forces tool choice. Current adaptive-only
  Anthropic models such as Fable 5.1 and Opus 5.5 reject forced tool use. Use
  the catalog capability contract when choosing request options; still require
  the actual opaque tool result and cache counters on every observed turn.
  Neither avoiding an unsupported option nor seeing a cache hit alone proves
  the specified multi-turn tool journey.
- The provider runner's default model table predates the refreshed catalog.
  Reconcile defaults with the §8.10 `get_latest_model(provider)` smoke contract
  while preserving explicit `ATTRACTOR_<ID>_MODEL` overrides and clearly
  recording the selected model. Do not silently describe an older explicit
  model's smoke result as proof about the current catalog default.

## Batch 2 proof contract — paired scope review approved, 2026-09-24

Use one Sol implementer after batch 1 is reviewed and integrated. Extract an
ordinary `live.provider-matrix-journeys` namespace; keep environment selection,
credential resolution, reporting and command dispatch in the executable. The
CLI and deterministic tests must call the same row functions. Supply adapter
options to the harness so requests still traverse actual native adapters and
the recording server. Retain existing row names, selection semantics and
compatible-endpoint behavior; do not require `ns main` from a test.

Preservation evidence must check the fifteen existing named rows and their
relative order, uniqueness, selection and compatible-endpoint behavior; retain
the existing predicate regressions and exercise representative older rows
through the shared runner. Provider-options, both image rows and invalid-key
construct additional adapters: preserve harness routing (base URL/transport)
when building those clients, together with each row's observer or invalid key.
An extracted row must not escape to a live endpoint during deterministic tests.
Test changed rows across all three protocols; moving unchanged functions does
not by itself require every old row to be rerun on every protocol.

- Basic generation must prove nonblank text, positive input/output tokens and
  normalized stop completion from that same result. Separate usage-accounting
  results do not supply this proof. Reject empty text, missing/zero counts and
  a non-stop completion independently.
- Streaming must consume real native events and require at least one text
  delta whose concatenation equals the nonempty final response text. Reject
  absent or mismatched deltas. Preserve the existing requested-answer check.
- Parallel tools must have two distinct call IDs in one step, successful
  results matching those IDs and their opaque values, observed overlap of the
  actual executors, at least two model steps, and both values in the final
  continuation. Reject serial execution, missing/unmatched results, an absent
  continuation and an answer that ignores either result.
- Structured extraction must use the known input "Alice is 30 years old" and
  validate exactly the expected name and integer age through generate-object.
  A schema-valid different person or age must fail the row.
- Missing-model smoke must request a deliberately nonexistent model through
  the configured native adapter and observe HTTP 404 normalized to :not-found
  with :retryable false. Set a positive retry allowance, then prove only one
  actual request occurred; setting retries to zero alone does not prove
  non-retryability. Record the requested missing model in row detail.
- Rate-limit evidence gets one normal short request with automatic retries
  disabled. A pass requires observed HTTP 429, normalized :rate-limit and
  :retryable true. An ordinary successful response means the condition was
  not observed and the row is explicitly skipped/unproved, with a reason.
  Other failures retain their actual category; quota/billing failures cannot
  pass from a rate-limit-like message. Do not induce account exhaustion or
  loop until a 429 occurs. Scripted 429s prove the runner and normalization
  only, never native-provider availability.
- Report an explicit incomplete aggregate when an applicable selected row is
  unproved. A successful request in the rate-limit row cannot produce a report
  claiming all selected journeys passed. Retain the distinction between an
  unobserved required native condition and an intentionally unsupported
  compatible-endpoint capability. Record selected/available rows and reasons;
  align CLI summary and exit documentation with the aggregate behavior.
- Prompt-cache requests must respect the selected model's forced-tool-choice
  capability, including adaptive-only Anthropic models. Still require each
  opaque turn result and all five turns' cache counters. A fixture that omits
  the tool on an auto-choice turn must fail. Test a legacy-capable model too.
- Default selection must use the current catalog for the native protocol,
  including registered aliases, while preserving explicit model overrides and
  recording the actual selected model. Compatible endpoints still require an
  explicit model. This policy must be independently testable without secrets.
- Close the agent-loop session and clean its temporary root in finally on
  success and failure, retaining bounded diagnostics before removal. Verify
  this through the shared runner, including an execution failure.

The native recording fixture must derive opaque continuation answers from
the actual submitted tool results, not fabricate success from a request
counter. Assert each required submitted input at the wire boundary: generation
and stream prompts, stream mode, extraction input/schema, and the deliberate
missing model in the native body or URL. A fixture keyed by scenario URL alone
must not certify a row after those inputs are lost or changed. Include controls
for wrong extraction input and a valid model substituted into missing-model
smoke. Test generation, streaming, parallel, extraction and both error rows
through all three native protocols. Predicate corruption controls supplement
these journeys; they cannot replace them. Preserve batch 1 fixture behavior
and include its focused regressions after changing the shared server.
No production interception API, smoke-session implementation or catalog
packaging belongs to this batch. Confirm production defects separately before
expanding scope. Root records scenarios, roadmap status and integration proof.

### Confirmed Gemini continuation dependency — 2026-09-24

A read-only review and a local public-API probe confirmed that normalized Gemini
function-call parts lose `thoughtSignature` before the next native request.
The probe used `llm/generate` with an actual Gemini adapter and a recording
transport: two requests completed, but the second request's model part contained
only `functionCall`, with the supplied opaque signature absent. Separately,
`agent/history-to-messages` reconstructs assistant messages from text and tool
calls, so preserving signatures only in the adapter would leave agent tool
continuations broken.

Google's [thought-signature guide](https://ai.google.dev/gemini-api/docs/generate-content/thought-signatures)
requires Gemini 3 function-call continuations to return the original opaque
signature on its original part; missing required signatures cause HTTP 400.
Gemini 2.5 signatures are optional, but returned values still need preservation.
Do not fabricate signatures, shift them to another part or combine signed parts.

Include this bounded production dependency in batch 2. The Sol implementer must
first add failing native continuation tests, then preserve signed normalized
parts through completion, streaming accumulation, high-level tool continuation
and agent history replay. Preserve public text/history behavior and portable
tool-call IDs; do not expose a new interception API or blindly forward Gemini
native parts to another provider. Preserve signatures on text/empty-text and
function-call and `thought:true` parts, including parallel calls where only the first is signed
and later sequential tool steps with distinct signatures. Unchanged unsigned
responses must retain their existing behavior.

The fixture must reject a continuation that omits, moves or alters a returned
signature, so shared provider journeys cannot pass solely because a permissive
script ignores this native contract. Cover complete and stream responses plus
high-level and agent continuations through public interfaces, with focused
non-Gemini regressions for affected message/history handling. This dependency
does not expand the work to the newer Interactions API or claim live account
parity. Scope reviewers must assess this boundary together with the runner work.

### Adjacent signed-history dependency — 2026-09-24

The same agent history reconstruction also drops Anthropic's already-normalized
thinking blocks and their signatures. Its [thinking guide](https://platform.claude.com/docs/en/about-claude/models/extended-thinking-models)
requires those complete blocks to accompany tool-use continuation. The Gemini
repair must not leave the provider runner's Anthropic agent-loop proof relying
on a fixture that omits this native requirement. Add a strict public native
agent continuation regression first, then retain signed and redacted Anthropic
parts through the same bounded history fix if that test confirms the loss.
Preserve visible text/history behavior and provider isolation. This adds no
new auth, compaction or model-switching feature. Record the behavioral RED/GREEN
and include the adjacent dependency in independent review and integration.

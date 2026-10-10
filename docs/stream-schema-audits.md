# Stream & Schema Audits — Consolidated

## Stream Accumulator Audit

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

---

## Stream Segment Completion

# Stream Segment Completion — Audit & Plan

## Native Stream Completion Audit

# Native stream completion audit

At baseline `5e811b1`, all three native adapters emit text and reasoning end
events without the final accumulated segment value required by the pinned
[unified LLM spec §3.14](upstream/strongdm-attractor/unified-llm-spec.md).
The event record in §3.13 is illustrative and does not list completion-value
fields; §3.14 explicitly requires those values. The existing compatible-adapter
reasoning fix uses `:reasoning`, keeping `:reasoning_delta` incremental-only.
Use `:text` analogously for completed text.

## Reproduction

Run from the repository root with the local Go-based runtime:

```sh
/Users/ndn/development/let-go/lg -source-paths src test/probes/stream_completion_check.lg run
```

This calls the public `llm/stream` API with an injected, offline SSE transport.
It sends two reasoning chunks and two text chunks per native provider. It makes
no network requests, needs no real credentials, and prints EDN records.

Observed on 2026-09-07: exit **1**, six failed completion checks. OpenAI,
Anthropic and Gemini each emitted the expected deltas, one end event per kind,
and a finish event. Each text end lacked `:text`; each reasoning end lacked
`:reasoning`. Thus successful final generation and correctly accumulated deltas
do not establish the segment-completion contract. The default suite's previous
green result did not cover these fields.

The probe is outside the default suite as a small diagnostic companion.
It is not a provider parity test: there is no real HTTP transport, live model,
tool-call coverage, cancellation, or concurrent-segment coverage in this probe.

## Original root cause and repair requirements

- Anthropic already accumulates text/thinking in its indexed block state, but
  `content_block_stop` emits only type, ID and raw metadata.
- Gemini already accumulates text/reasoning in stream state, but its finish
  path omits those values from end events.
- OpenAI tracks started/ended IDs without accumulating text/reasoning deltas.
  Its text-done, reasoning-done, content-part-done and message-item-done paths
  omit completed values. Review segment identity (including content indices)
  before introducing a buffer keyed only by item ID.

The repair must cover all applicable completion paths, not just the exact
fixtures above. Permanent tests should verify interleaved segment isolation,
empty segments, authoritative done payloads versus delta accumulation, duplicate
completion suppression, and preservation of final response/tool/usage data.
Redacted Anthropic thinking must remain opaque; do not invent visible reasoning
from encrypted data or expose it as ordinary text. Check compatible-adapter
text completion too; its earlier fix addressed only reasoning.

The initial audit changed no production code or let-go runtime. This is a
reproduced Attractor normalization gap, not an upstream let-go bug. The full
implementation goal remains incomplete.

## Protocol cross-check

The [official OpenAI streaming event reference](https://developers.openai.com/api/reference/resources/responses/streaming-events)
was fetched on 2026-09-07. Text and reasoning-text deltas/done events identify
both the item and its content index. Done events carry full text; content-part
done carries the finalized part, and item-done carries the item's content array.
Reasoning summaries use a separate summary index. This supports buffering by
segment rather than item alone and testing completion through each event path.
The field names of normalized completion values remain an Attractor API choice
guided by the pinned typed-completion requirement, not OpenAI wire field names.

## Implemented contract

Text end events now carry `:text`, and reasoning end events carry `:reasoning`,
across the three native adapters; compatible text completion is also covered.
OpenAI buffers individual content parts, uses explicit done values (including
empty strings) when present, and otherwise falls back to initial text plus
accumulated deltas. Direct, part and item completion paths share deduplication.
Item completion also closes known segments when its content array is omitted.
Anthropic redacted reasoning contributes no plaintext; its opaque representation
is retained in the existing raw/final-response paths.
OpenAI summary/encrypted-only item completion retains its existing raw
`provider_event` passthrough; it does not manufacture reasoning text events.

OpenAI index-zero IDs retain their item ID unless it begins with the reserved
`segment:` prefix. Other IDs encode the item length, item ID and content index.
Consumers should treat IDs as opaque correlation keys, not parse their spelling.
End values are never repeated under the delta keys, and existing accumulators
continue to append only delta events.

The permanent `attractor.stream-completion-test` namespace covers this contract
through the public high-level streaming API with offline provider transports.
`test/runner.lg attractor.stream-completion-test` is a direct/bundled entrypoint for the same tests.
Native duplicate transport-packet handling and OpenAI reasoning-summary event
normalization remain separate streaming work; this change does not establish
full streaming conformance, live provider parity, or complete Attractor support.

## Mechanical verification

- Initial permanent tests: 3 tests, 36 assertion failures, zero errors before
  implementation. Expanded tests then caught ID-collision and fallback gaps.
- Review caught lost opaque-item passthrough; the added regression produced
  six assertion failures before the corrective change.
- Final focused tests: 11 tests, 143 assertions, zero failures/errors, exit 0.
- Final worktree full suite: 588 tests, 4,923 assertions, zero failures, exit 0.
- Fresh main full suite after integrating `6353f57`: the same 588/4,923/0, exit 0.
- Combined LLM/Qwen/completion tests: 101 tests, 694 assertions, zero failures.
- The same 11/143 checks pass in a standalone bundle run from `/tmp`, exit 0.
  This is packaged let-go bytecode evidence, not native Go AOT lowering.
- Original six-check probe: all three providers pass, exit 0.
- `lgx build` and the rebuilt CLI's `help` command both exit 0.
- Independent spec and quality reviews approve after the passthrough repair.

Bundle verification commands (choose an existing temporary destination):

```sh
/Users/ndn/development/let-go/lg -source-paths src:test -b /tmp/stream-completion-check test/runner.lg attractor.stream-completion-test
```

Run that binary with `run` from outside the checkout. The explicit entrypoint
requires both the implementation and test namespaces so test discovery survives
bundling, and returns a failing exit status when any assertion fails.

---

## Implementation Plan

# Stream Segment Completion Implementation Plan

> Use subagent-driven-development with test-first implementation and independent spec and quality review.

**Goal:** Fulfil pinned unified-LLM §3.14 typed completion for text and reasoning segments across native and compatible adapters.

**Architecture:** Keep provider-specific stream normalization in `src/attractor/llm.lg`. End events carry `:text` or `:reasoning`, never replay their value as a delta. Reuse indexed Anthropic blocks and Gemini/compatible buffers. OpenAI needs per-segment accumulation and completion deduplication, using content indices to avoid mixing multiple parts of one item. Preserve raw events and final response semantics. Redacted thinking remains opaque.

**Tech stack:** Local Go-based let-go, existing JSON/SSE transport seam, clojure.test. No JVM APIs, dependencies, live models, or runtime edits.

## Implementation task

- [x] Add `test/attractor/stream_completion_test.lg` with public `llm/stream` offline SSE cases. Assert completed values, exact Unicode/whitespace, empty segments, interleaved segments, duplicate completion, done-only and delta-only fallback, raw metadata, and final response/tool/usage preservation. Cover Anthropic redacted thinking without inventing plaintext. Cover compatible text as well as native text/reasoning.
- [x] Run focused tests and observe assertion failures before changing production code:
  `/Users/ndn/development/let-go/lg -source-paths src:test -e '(require (quote harness.tests) (quote attractor.stream-completion-test)) (harness.tests/run-and-exit! (quote attractor.stream-completion-test))'`
- [x] Implement missing end values and required segment isolation. Preserve IDs for unindexed/single-index-zero streams when possible, with collision-free IDs for additional indexed segments. All applicable OpenAI done paths must use the same segment state and suppress duplicate completion. Prefer explicit native done text when supplied (including empty), otherwise accumulated deltas. Do not broaden this into transport cancellation or whole-provider parity.
- [x] Re-run focused tests, existing `attractor.llm-test` and `attractor.qwen-reasoning-test` together; fix regressions.
- [x] Independent spec review, then quality review; resolve findings.
- [x] Parent runs full `env PATH="/Users/ndn/development/let-go:$PATH" lgx test`, build, standalone bundled focused tests, and the original audit probe. Only one full suite at a time; do not edit tests during it.
- [x] Update audit evidence, commit scoped files, integrate and push only after verification. Preserve all other worktrees and private `docs/notes.md`.

## Baseline and limitations

Baseline `5e811b1`: existing LLM suite 83 tests / 494 assertions / zero failures. The root offline probe reports six missing native completion fields. Native HTTP/live model coverage remains separate. This task is not full Attractor completion.

Delivered as `6353f57`, fast-forwarded into main and pushed on both main and
stream-completion. Fresh main verification passed 588 tests / 4,923 assertions /
zero failures, and rebuilt CLI help exited 0. Worktrees and private notes remain.

---

---

## Streaming HTTP Errors

# Streaming HTTP Errors — Plan & Implementation

## Repair Plan

# Streaming HTTP error-body repair

Scope: pinned unified LLM §§6.1–6.4 require provider error fields and retry
classification. Current native streaming HTTP error bodies are readers, but
`provider-error` stringifies the reader, losing JSON codes, quota classification
and raw response data. Repair the native/compatible streaming boundary without
changing the public pure string/map error normalizer or success-event behavior.

1. Add `test/attractor/stream_http_error_test.lg` exercising public stream/client
   APIs with reader error bodies for OpenAI, Anthropic, Gemini and compatible.
   Show RED: quota429 should be nonretryable with code/raw; auth401 no retry;
   transient429 honors Retry-After and bounded attempts. Preserve string/map
   injected transports. Check body closure (also on parse/read failure).
   Include a held error body after headers: high-level abort must close/unblock
   reading, raise `:abort`, avoid retry, and settle cleanup. Test abort racing
   closer registration and idempotent repeated closure; ordinary read errors
   preserve HTTP classification but cancellation stays distinct.
2. In `src/attractor/llm.lg`, introduce a small streaming HTTP error helper that
   registers a reader's idempotent closer before consuming it, reads actual text,
   normalizes the error and closes in finally. Wire all four streaming adapters.
   Do not change successful SSE behavior. Preserve status classification if
   body decoding fails; cancellation must still be able to close a held body.
3. Parent validates real socket error responses through existing native HTTP,
   checking requests counted by the server. No model endpoint or real key.
4. Independent spec then quality review. Run focused+existing LLM/Qwen tests,
   full suite once files freeze, build and standalone bundle; commit/push scoped
   changes after verification. Preserve all other worktrees/private notes.

Use local Go-based let-go, not JVM APIs. Runtime #816 still limits cancellation
before headers; this repair must not claim to solve it or full transport parity.
Native connect/request/read deadlines remain separate work. Reading an error
body must not make high-level cancellation unable to close the known body.

---

## Implementation & Evidence

# Streaming HTTP errors

Native streaming transports return a reader even for a non-200 response. At
baseline `25aa00a`, the adapters passed that reader to the string/map error
normalizer. Its object representation replaced the JSON body, losing `raw` and
`error_code`; a 429 quota error became a retryable rate-limit error.

The four streaming adapters now consume error-body readers before normalization
and close them in `finally`. An idempotent closer is registered before reading,
including the race where cancellation has already happened. String/map/nil
injected transport bodies retain their old path. Ordinary body-read failures
retain status-based classification rather than turning a 401 into a generic
retryable exception. Successful SSE event handling is unchanged.
The controlled call also rechecks cancellation after its worker result arrives,
so an interrupted read cannot race past the pre-wait check and surface as an
authentication/rate-limit error instead of an abort.

## Evidence

The new `attractor.stream-http-error-test` suite has eight tests / 208 assertions.
Before implementation, the initial five tests had 40 failures; the expanded
seven-test suite produced 60 failures against baseline production code. Review
then identified the post-wait cancellation race; its deterministic gated test
produced four failures before the fix. Final focused execution passes all 208
assertions, and the combined LLM/Qwen/error suite passes 98 tests / 759 assertions.
The same 8/208 tests pass as a standalone bundle executed outside the checkout.
This is packaged bytecode evidence, not native Go AOT lowering. `lgx build` and
the rebuilt CLI's `help` command also exit 0. Spec and code-quality reviews approve.
Final worktree full suite: 596 tests, 5,131 assertions, zero failures, exit 0.
Fresh main verification after integrating `9543aaa` passes the same 596/5,131/0;
the rebuilt main CLI's `help` also exits 0.

Real socket checks use `test/probes/http_error_server.go` and `test/probes/http_error_check.lg`:

```sh
go run test/probes/http_error_server.go
# In another shell, replace URL with the loopback address it prints:
/Users/ndn/development/let-go/lg -source-paths src test/probes/http_error_check.lg URL
```

All 13 cases pass, exit 0, with independent server request counts:

- OpenAI, Anthropic, Gemini and compatible: quota429 and authentication401 each
  make one request and retain raw JSON/code with `retryable=false`.
- Each adapter's rate-limit429 makes exactly three requests. The injected sleep
  callback receives two 0.02-second delays from Retry-After. This proves delay
  selection and retry bounds, not elapsed wall-clock backoff scheduling.
- An OpenAI 401 whose body stalls after headers returns `:abort`, makes one
  request, closes its connection (server context canceled), and settles all
  workers in its scope within a one-second observation window before release.

The first held-body run sampled a transient live worker immediately after server
cancellation. The corrected checker waits boundedly for worker settlement. It
does **not** prove the worker is joined before the public caller returns.
The fixture drains request bodies before readiness, binds only loopback, and
has 10-second held-response / 60-second server safety bounds. Successful runs
shut it down explicitly; observed fixture processes exit 0. No real API keys or
model endpoint are involved. Fixture Go code is infrastructure, not production.

## Remaining transport requirements

[let-go #816](let-go-runtime-issues.md) remains: requests blocked before
headers do not inherit scope cancellation. Attractor still needs joined worker
and stream-monitor ownership, native connect/request/read deadlines, stalled
success-body coverage, and the broader provider/session error matrix. An error
body can still block without caller cancellation/timeout; this change does not
provide the missing native default read deadline. It repairs error normalization
and known-body closure, not full ULLM-CANCEL-01/ULLM-ERROR-01 conformance.

---

---

## Terminal Streaming Errors

# Terminal Streaming Errors — Plan & Implementation

## Implementation Plan

# Terminal streaming failures

Pinned unified LLM §§3.13, 6.1–6.6 require SDK errors and prohibit retry after
partial data delivery. Current Anthropic error+message_stop emits error+finish;
native Gemini error frames are ignored and OpenAI failure details may be nested
under response.error. The compatible path suppresses later normalized events
but can keep consuming the wire tail.

1. Add test/attractor/stream_terminal_error_test.lg with public native low-level,
   configured-client and high-level streams for all four adapters. Show RED:
   partial text then error then late text/tool/finish must end at one error;
   preserve partial response/text, raw provider event and SDK error fields.
   No retries, tool execution, or second provider call after partial failure.
   Include first-event errors and a lazy tail that throws/blocks if consumed.
   After terminal failure, high-level :response must raise the retained SDK
   error; :partial_response and :text_stream preserve delivered partial output.
   Exercise this distinction for native and custom-adapter first/partial errors.
2. Modify src/attractor/llm.lg: normalize native error payloads to SDK-compatible
   exceptions while retaining event.raw. Cover OpenAI response.failed nested
   response.error and error events, Anthropic error, Gemini error, compatible
   error. A terminal sequence boundary must emit the error once, close its owned
   body, and not realize later native/normalized events. Apply the same stop
   rule to custom client-adapter error events at the high-level boundary.
   Preserve existing already-typed errors and successful stream semantics.
   Update old tests that expected raw maps under :error to check typed fields
   and the retained raw event instead. Do not fabricate a success FINISH.
3. Parent extends loopback HTTP fixture and adds a checker: send partial data,
   an error, then hold the connection; assert one request, partial output,
   typed error, no retry/late frames, and server-observed close before release.
4. Independent spec/quality review, focused regression suites, final full suite,
   bundled tests and build. Commit and push scoped changes after verification.

Do not rewrite generic transport cancellation or promise native default timeouts.
Before-headers cancellation (#816), monitor/worker join-before-return, provider
release parity and other stream lifecycle requirements remain separate. Use
native Go-based let-go APIs; no runtime checkout changes or live model requests.

---

## Contract & Evidence

# Terminal streaming errors

The unified LLM specification (§§3.13 and 6.6) requires typed SDK errors and no
automatic retry after partial delivery. This change makes explicit provider
error events terminal across OpenAI Responses, Anthropic Messages, native Gemini,
and the separate OpenAI-compatible adapter.

Before this change, Anthropic could emit `:error` followed by `:finish`, Gemini
ignored native error frames, and the compatible adapter suppressed late events
but still consumed the wire tail. OpenAI failed responses also needed their
nested `response.error` normalized.

## Contract

- Emit one terminal `:error`, containing an SDK exception under `:error` and the
  original provider event under `:raw`.
- Retain provider/category/code/retryability and actual available status data.
  Gemini's numeric native HTTP error code is retained as status; other numeric
  provider codes are not assumed to be HTTP statuses. SDK error codes are strings.
- Close an owned native body once without realizing the next frame. Apply the
  same terminal boundary to custom adapters in high-level streaming.
- Preserve delivered output in `:text_stream` and `:partial_response`; after
  failure, calling `:response` throws the retained error instead of returning a
  partial response as successful completion. Accessors do not implicitly drain
  the stream.
- Never process later text, reset, tool, or finish events, execute later tools,
  or retry the failed stream. An error may be intrinsically retryable without
  this already-started stream being retried.

## Mechanical evidence

`test/attractor/stream_terminal_error_test.lg` covers native low-level,
configured-client, and high-level first/partial errors, typed classifications,
custom adapters, poisoned lazy tails, close idempotence, and final versus partial
responses. Corrected initial fixtures produced 197 failing assertions before
implementation; additional classification assertions produced 18 failures before
their fix. Final focused result: **7 tests, 346 assertions, no failures/errors**.
The impacted LLM, Qwen reasoning, segment completion, HTTP-error, and terminal
suites passed **116 tests / 1,249 assertions**.

The final feature-worktree default suite passed **603 tests / 5,478 assertions,
zero failures**, exit 0. `lgx build` and `bin/attractor help` exited 0. The focused
runner was compiled with local let-go into a standalone bundle and run from
`/tmp`: **7 tests / 346 assertions**, zero failures/errors. This exercises packaged
bytecode, not native Go AOT lowering. Independent spec and quality reviews passed.

Real HTTP verification uses the bounded, loopback-only fixture:

```sh
go run test/probes/http_error_server.go
# In another terminal, substitute its printed loopback URL:
/Users/ndn/development/let-go/lg -source-paths src \
  test/probes/stream_terminal_http_check.lg http://127.0.0.1:PORT
```

All **four cases passed**. Each provider sent `partial`, an error, then late text
while holding the HTTP response open. Each client completed with one typed error,
retained `partial` in both output views, raised the same error data from
`:response`, and made exactly one request with no retry delay. The server observed
each connection's cancellation and zero held handlers before explicit checker
cleanup; cumulative cancellation counts were 1, 2, 3, and 4. No live model calls.
An initial checker run used the wrong partial-response field (`:text` rather than
`[:message :text]`); it was corrected before this passing run and is not RED
implementation evidence.

The existing `test/probes/http_error_check.lg` was also rerun against the extended
fixture: all **13 HTTP-error cases passed**, including the held-body abort case.

## Remaining boundaries

This does not establish generic before-headers HTTP cancellation, worker or
monitor join-before-return, default native deadlines, all provider release/live
parity, or duplicate non-error event handling. See
[the HTTP cancellation evidence](let-go-runtime-issues.md) and upstream
[#816](https://github.com/nooga/let-go/issues/816).

The fixture encoder temporarily keywordizes its fixed string keys because of
confirmed let-go [#817](https://github.com/nooga/let-go/issues/817). This is only a
test-fixture workaround, not an application-wide JSON key conversion. Internal
application serialization remains `.edn`.

---

---

## Structured-Output Schema Audit

# Structured-output schema audit

Unified LLM sections 4.5 and 4.6 require final structured outputs to be validated.
The local validator ignored `patternProperties`. That accepted invalid values
under matching keys and, when `additionalProperties` was false, rejected valid
keys that should have been admitted by a pattern.

The object validator now checks every matching pattern schema, alongside any
explicit property schema, and excludes pattern-matched keys from additional
properties. Matching is unanchored unless the schema provides anchors. Boolean
schemas and local references use the existing recursive validator. Semantics
follow the [JSON Schema object reference](https://json-schema.org/understanding-json-schema/reference/object#patternProperties).

`pattern_properties_contract_test.lg` covers matching and extra keys, overlapping
patterns, explicit properties, boolean rejection, local references, and a public
`generate-object` failure for invalid model output. Eight assertions failed
before the change; four tests/11 assertions pass afterward. Existing LLM tests
(83/495), structured-stream tests (4/9), and build pass.

This repairs one missing keyword, not complete JSON Schema dialect conformance.
The implementation uses the runtime's regular-expression engine; full ECMA-262
regex compatibility is not established. Other dialect keywords and recursive
reference termination still need assessment. Partial-object display filtering
is separate from final validation and is not expanded by this change.

## Conditional schemas

The validator also ignored `if`/`then`/`else`, allowing final objects to omit
fields required by the selected branch. It now validates `if` against the
instance, applies only the selected `then` or `else` schema, and treats an
omitted branch as unconstrained. Without `if`, standalone `then` and `else`
remain ignored. Boolean schemas and string-key schemas are supported.
These rules follow the [JSON Schema conditional reference](https://json-schema.org/understanding-json-schema/reference/conditionals#if-then-else).

`conditional_schema_contract_test.lg` exercises discriminator-dependent required
fields, missing branches, false schemas, and final streamed-object rejection.
Seven assertions failed before the fix; three tests/13 assertions pass afterward.
Pattern-property (4/11), LLM (83/495), structured-stream (4/9), and build checks
also pass. This adds conditional branch validation, not a claim that every
JSON Schema keyword is implemented.

## Property dependencies

The object validator now enforces `dependentRequired`, `dependentSchemas`, and
the older `dependencies` form. Array dependencies extend required properties;
schema dependencies validate the whole instance, independently of its ordinary
property constraints. A triggering property is tested for presence, so false
and null values still activate dependencies. Dependencies remain directional.
The [conditional reference](https://json-schema.org/understanding-json-schema/reference/conditionals)
documents both modern keywords and their legacy form.

`schema_dependencies_contract_test.lg` covers absent, false, null, and true
triggers; required-property presence; whole-object schema validation; boolean
rejection; and local references. Twelve assertions failed before the change;
three tests/26 assertions pass afterward. Conditional-schema (3/13),
pattern-property (4/11), LLM (83/495), and build checks also pass.

## Array gaps reproduced after the object-schema repairs

A native let-go probe of `validate-json-schema` produced these results:

| Instance | Schema | Observed | Required |
| --- | --- | --- | --- |
| `["wrong"]` | `{"type":"array","contains":{"type":"integer"}}` | Valid | Invalid: no matching item |
| `["wrong"]` | `{"type":"array","prefixItems":[{"type":"integer"}]}` | Valid | Invalid: first item has wrong type |
| `[1]` | `{"type":"array","items":[{"type":"integer"}]}` | Invalid: schema must be object or boolean | Valid under legacy tuple syntax |

The [JSON Schema array reference](https://json-schema.org/understanding-json-schema/reference/array)
describes these constraints and the draft-specific tuple forms. Source inspection
confirms the current array validator supports cardinality, uniqueness, and a
single repeated `items` schema, but not tuple positions or containment. These
are reproduced implementation gaps, not credential-dependent live-test gaps.
The next array work must also cover bounds on matching items and constraints
on items beyond a tuple's prefix. Dialect selection and unevaluated-item
tracking remain separate unresolved questions.

Integrated verification after the default-client and object-schema repairs:
`make test` exited 0 with 1096 tests, 9976 assertions, and zero failures.
Log: `/tmp/attractor-shared-transport-suite.log`. This result confirms the
current regression suite passes while the array gaps above remain reproduced.
ULLM-STRUCTURED-01 is therefore marked partial in the requirement ledger.

## Array constraints repaired

The reproduced array gaps above are now fixed. `prefixItems` validates each
present position; modern `items` constrains only the tail. Legacy array-valued
`items` supplies the positions and `additionalItems` constrains its tail.
Unspecified tail schemas allow additional values, and missing prefix positions
do not imply a minimum array length. Ordinary schema-valued `items` continues
to validate every item and ignores legacy `additionalItems`.

`contains` now requires a matching item by default, with `minContains` and
`maxContains` applying to the matching subset. A zero minimum permits no
matches, including with `contains: false`. Bounds without `contains` are ignored.

`array_schema_contract_test.lg` covers positions, tails, ordinary items,
containment bounds, and boolean schemas. Thirteen assertions failed before the
repair; four tests/32 assertions pass afterward. LLM (83/495), structured-stream
(4/9), and build checks pass. The full-suite result above predates this repair.
Dialect selection, unevaluated annotations, and remaining keywords still require
assessment, so the structured-output ledger stays partial.

## JSON equality

`enum`, `const`, and `uniqueItems` previously used host-language equality,
which distinguishes integer `1` from decimal `1.0`. JSON Schema requires
numerically equal values to compare equal, including within arrays and objects
([instance equality](https://json-schema.org/draft/2020-12/json-schema-core#section-4.2.2)).
These constraints now share a recursive comparison representation that normalizes
integral numbers to exact big integers. Large integers are not first rounded
through floating point. Validation does not mutate the original values.

`schema_equality_contract_test.lg` checks primitive and nested equivalence,
duplicate array values, array order, type distinctions, and adjacent large
integer/decimal values beyond double's exact integer range. Six assertions
failed before the fix; two tests/17 assertions pass afterward. Array tests
(4/32), LLM tests (83/495), and build pass. This does not restore precision
already lost by a JSON decoder or establish arbitrary-precision decimal parsing.

## Property names

`propertyNames` previously had no effect. The object validator now applies its
subschema to each key independently of the associated value, following the
[property-name contract](https://json-schema.org/understanding-json-schema/reference/object#property-names).
Boolean schemas and local references retain their usual semantics; an empty
object satisfies even `propertyNames: false` because it has no keys to reject.

Five assertions failed before the repair. The property/pattern namespace now
passes six tests/19 assertions, covering invalid patterns, short and empty keys,
empty objects, boolean rejection, and local references. LLM (83/495), dependency
(3/26), conditional (3/13), array (4/32), and equality (2/17) tests pass, as do
the build and whitespace check. The full-suite result above predates this repair.
Dialect selection and unevaluated annotation tracking remain unresolved.

## Array indices in local references

The reference audit confirms that both a referenced schema and its sibling
constraints apply. It also reproduced invalid array-index handling: `00` and
`01` resolved successfully, and an oversized decimal index threw instead of
returning an unresolved-reference result. The resolver now requires canonical
array indices and handles numeric overflow as an unresolved reference, following
[RFC 6901 section 4](https://www.rfc-editor.org/rfc/rfc6901.html#section-4).
Object keys such as `01` retain their literal meaning.

`schema_reference_contract_test.lg` passes two tests/12 assertions after three
assertions failed before the fix. The LLM namespace initially reported two
failures in existing timeout tests (idle-stream cleanup after a fixed 25 ms
sleep, and an exact attempt count under a 10 ms total deadline). An unchanged
rerun passed 83 tests/495 assertions and the build passed. This is evidence of
intermittent failures requiring investigation, not proof of reliable deadline
tests. Logs: `/tmp/attractor-schema-reference-checks.log` and
`/tmp/attractor-schema-reference-recheck.log`. Full-suite verification has not
been rerun for this change. URI fragment decoding and cyclic references remain
outside this evidence.

## Timeout evidence follow-up

The two intermittent assertions above relied on scheduling within very small
windows. Idle cleanup now delivers a promise from the registered close callback;
the test waits for that callback before demanding any more stream events. It
therefore checks autonomous cleanup rather than assuming a 25 ms sleep was
sufficient. The stream uses a 500 ms deadline and a bounded two-second observation.

The retry-delay test now observes the actual retry callback and its five-second
delay following a rate-limit failure. It requires total timeout to return within
two seconds under a 500 ms deadline. This proves the retry path was reached and
its delay interrupted; an adapter-attempt counter alone could not establish that.
Production timeout code is unchanged. The focused LLM namespace passes 83 tests
and 496 assertions. These tests still require scheduling within their bounded
observation windows; they do not establish hard real-time guarantees.

Integrated verification after the array, equality, property-name, reference-index,
and timeout-test changes: `make test` exited 0 with 1106 tests, 10046 assertions,
and zero failures. Log: `/tmp/attractor-shared-transport-suite.log`. This supersedes
the earlier regression-run totals, not the unresolved conformance findings.

## URI fragment references

Local `$ref` fragments now undergo percent decoding before JSON Pointer
tokenization, as required by [RFC 6901 section 6](https://www.rfc-editor.org/rfc/rfc6901.html#section-6).
This handles UTF-8 names, encoded separators, literal percent signs and encoded
tilde escapes. Literal plus signs remain plus signs. The existing let-go
`io/decode :url` primitive uses query decoding, so literal `+` is protected before
that call. Percent decoding happens once; `%2520` names a literal `%20` key.
Malformed percent escapes and invalid pointer tilde escapes return unresolved
references rather than matching identically spelled object keys.

Eleven assertions failed before the repair. Reference tests now pass four tests
and 27 assertions, including empty names and `~01` escape ordering. LLM tests
(83/496), build, and whitespace checks pass. The full-suite result above predates
this change. Named anchors, dynamic references, resource scope changes via `$id`,
and cyclic-reference termination remain outside this evidence.

## Recursive reference termination

The validator followed local references without tracking active evaluations.
The new cyclic-schema namespace did not terminate against the old implementation;
the direct native runtime probe had to be stopped (exit 137). Its requested
five-second SIGALRM did not stop the runtime, so that alarm is not evidence of
a reliable deadline. The probe process was identified and explicitly killed.

Reference evaluation now carries an immutable set of active reference/value
pairs within each validation call. Re-entering the same pair aborts validation
with a cyclic-reference diagnostic. That error bypasses applicator boolean logic
and is converted to the public invalid result only at the outer boundary, so
`not` cannot turn the cycle into success. Descending into a finite tree and
reusing the same reference on equal sibling values remain valid. Unvisited
cycles in definitions, absent properties, or unselected branches are ignored.
This follows [JSON Schema core section 9.4.1](https://json-schema.org/draft/2020-12/json-schema-core#section-9.4.1),
which forbids infinite validation loops and leaves cyclic-schema results undefined.

`schema_recursion_contract_test.lg` passes 4 tests/22 assertions, including
completion and streaming object generation reporting `no-object-generated`.
Reference (4/27), array (4/32), conditional (3/13), LLM (83/496), structured-stream
(4/9), build, and whitespace checks pass.
Log: `/tmp/attractor-schema-recursion-checks.log`.
This addresses local-reference cycles; named anchors, dynamic references,
resource scope, full dialect conformance, and deep finite-input stack bounds
remain outside this evidence.

## Exact numeric multiples

`multipleOf` previously converted both operands to double and accepted quotients
near an integer using a tolerance. That accepted `0.1000000000000001` as a
multiple of `0.1`, erased odd parity above double's exact integer range, and
accepted tiny nonzero quotients near zero. Double overflow also rejected valid
large quotients. These violate the integer-quotient rule in
[JSON Schema validation section 6.2.1](https://json-schema.org/draft/2020-12/json-schema-validation#section-6.2.1).

The validator now uses native let-go `rationalize` on each operand and requires
their exact quotient to be an integer. The primitive preserves integer values
and uses the shortest decimal representation for floats, so `0.3` remains a
multiple of `0.1` without rounding a nearby different value into acceptance.
Non-finite numeric inputs cannot be rationalized and fail this constraint.

Ten assertions failed before repair. `numeric_schema_contract_test.lg` passes
4 tests/20 assertions after it, covering near-misses, negative instances, zero,
large integers, extreme scales, invalid divisors, and rejection through both
completion and streaming object generation. Equality tests (2/17), LLM tests
(83/496), structured-stream tests (4/9), build, and whitespace checks pass.
Log: `/tmp/attractor-numeric-schema-checks.log`.

This removes arithmetic approximation within this constraint; it cannot recover
precision already lost while decoding JSON. Arbitrary-precision JSON decoding
and complete schema meta-validation remain separate gaps. The integrated
1141/10264 suite result above predates this focused repair.

Integrated verification after the recursion guard: `make test` exited 0 with
1141 tests, 10264 assertions, and zero failures.
Log: `/tmp/attractor-recursion-integration-suite.log`.
A focused independent review found no blocking correctness issues in the guard
or omitted-model routing; it did not claim exhaustive schema or provider coverage.

## Named anchors and embedded resource scope

Fragment-local `$ref` now resolves `$anchor` and static `$dynamicAnchor` targets
after URI decoding. Discovery visits schema-valued keyword locations, ignores
annotation data, and stops at embedded `$id` resource boundaries. Invalid names,
missing targets, and duplicate anchors fail resolution. Ordinary reference
siblings still apply. These rules follow
[JSON Schema core section 8.2.2](https://json-schema.org/draft/2020-12/json-schema-core#section-8.2.2).

Direct evaluation and JSON Pointer traversal both preserve the nearest embedded
resource as the base for subsequent local references. Cycle detection includes
that resource alongside the reference and instance value.

Twelve anchor assertions failed before implementation; six additional embedded
resource assertions failed before the scope repair. The final anchor namespace
passes 6 tests/36 assertions, pointer references 4/27, recursion 4/22, LLM 83/496,
and structured streaming 4/9. Build and whitespace checks pass. A focused
independent review found no important issues within this local-reference scope.
Log: `/tmp/attractor-schema-anchor-final-checks.log`.

Absolute and relative URI references, dynamic `$dynamicRef` scope, dialect
selection, and full schema meta-validation remain unimplemented. Static use of
`$dynamicAnchor` does not provide dynamic-reference support.

Integrated verification: `make test` exited 0 with 1153 tests, 10330 assertions,
and zero failures. Log: `/tmp/attractor-schema-anchor-suite.log`.

---

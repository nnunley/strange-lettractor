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

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

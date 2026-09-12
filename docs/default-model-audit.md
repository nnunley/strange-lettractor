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

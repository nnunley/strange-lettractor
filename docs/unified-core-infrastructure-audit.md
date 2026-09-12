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

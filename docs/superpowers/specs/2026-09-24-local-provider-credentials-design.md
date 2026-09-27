# Local Gemini OAuth and Anthropic OIDC credentials

Status: user selected Attractor-native browser login on 2026-09-24; implementation
planning is in progress. Cloud setup has not started.

## Outcome

The local desktop/CLI can call the native Gemini Developer API and native
Anthropic API using short-lived bearer tokens. EDN declares credential profiles
and provider bindings. Selecting a profile must actually exercise that profile,
even when a funded API key remains in `.env`.

The user selected both providers and the local desktop/CLI. Preserve the native
endpoints and verify the intended funded project/workspace during setup.

## Selected approach

Use Attractor's own browser login, reusing its PKCE, loopback callback and OS
keychain primitives. The user selected this over the proposed gcloud/ADC
bootstrap. A Google desktop OAuth client remains a setup prerequisite; Attractor
handles consent, code exchange, refresh persistence and subsequent token refresh.
It opens the system browser and receives the result on a local loopback listener.

The alternatives considered were gcloud bootstrap followed by in-process
refresh, and invoking gcloud during inference. Neither is part of this version.
Existing global ADC files are not read or changed. Refresh tokens persist only
in the OS keychain; access and identity tokens remain in memory. A protected
Google desktop-client JSON file supplies the client metadata for login/refresh.

## Observed local prerequisites

Read-only inspection on 2026-09-24 found:

- `gcloud` has an active user login.
- Existing ADC is `authorized_user`, mode `0600`, with quota project
  `personal-dev-238215`. CLI login and ADC are distinct identities; do not assume
  that an active CLI login proves ADC has the right account or scopes.
- `norman-prime-ws-20260812` is active and billing-enabled under
  `015DD1-0A5277-AA114F`, the previously verified Norman's Projects account.
- The listed service account is `hermes`; propose a dedicated
  `attractor-desktop` service account instead of borrowing its permissions.
- Neither `generativelanguage.googleapis.com` nor
  `iamcredentials.googleapis.com` appears in that project's enabled API list.
- The selected project's funded AI Studio association, OAuth desktop client,
  and Anthropic federation resources remain to verify. Reading the existing AI
  Studio tab through Chrome timed out; no project association was inferred.

The old ADC quota project must not silently select Gemini billing. The Gemini
profile requires an explicit quota project, verified against the funded AI Studio
project. The Google project used for the Anthropic identity can be separate.

## Module boundary

Expose three small credential namespaces, independent of the agent, MCP session,
model catalog and LLM message serialization:

- `attractor.credentials`: profile validation, resolution, expiry-aware cache,
  concurrent refresh coordination, safe status and invalidation.
- `attractor.credentials.google`: Google browser login, OAuth refresh and Google
  IAM Credentials ID-token acquisition using a referenced Google profile.
- `attractor.credentials.anthropic`: exchange a Google-issued identity token for
  an Anthropic access token scoped to the configured workspace.

Inject HTTP transport, clock, credential store, browser opener and client-file
reader at the boundary. This is
the extraction boundary for a separate Clojure/let-go credentials library. The
first implementation is a let-go module in this repository; publishing a library
and proving JVM compatibility are separate work.

`attractor.providers` retains configuration precedence and protocol header
selection. `llm` consumes resolved request authentication; it does not own token
exchange. Reuse `attractor.auth` browser primitives with explicit optional
Google consent/code-exchange parameters while preserving existing MCP behavior.
MCP-specific refresh policy is not pulled into LLM code.

## Proposed EDN shape

This is a design example, not configuration supported by the current build:

```clojure
{:credentials
 {"google-desktop"
  {:type :google-browser
   :client_file "/absolute/private/path/google-desktop-client.json"
   :scopes ["https://www.googleapis.com/auth/cloud-platform"
            "https://www.googleapis.com/auth/generative-language.retriever"]}

  "gemini-desktop"
  {:type :google-oauth
   :source "google-desktop"
   :quota_project "VERIFIED_AI_STUDIO_PROJECT_ID"}

  "anthropic-desktop"
  {:type :anthropic-google-oidc
   :source "google-desktop"
   :google_service_account
   "attractor-desktop@norman-prime-ws-20260812.iam.gserviceaccount.com"
   :organization_id "ANTHROPIC_ORGANIZATION_ID"
   :service_account_id "svac_REPLACE"
   :federation_rule_id "fdrl_REPLACE"
   :workspace_id "FUNDED_WORKSPACE_ID_OR_default"}}

 :providers
 {"gemini"
  {:protocol :gemini-generate-content
   :base_url "https://generativelanguage.googleapis.com/v1beta"
   :credential_profile "gemini-desktop"}

  "anthropic"
  {:protocol :anthropic-messages
   :base_url "https://api.anthropic.com/v1"
   :credential_profile "anthropic-desktop"}}}
```

The new top-level `:credentials` map follows the same user/project layering as
providers. A profile definition replaces the same named profile from a lower
layer. Validate the merged reference graph, reject cycles and unknown fields,
and preserve existing provider-only configuration and public APIs.

Files contain references and non-secret IDs, not token literals. Support only
the documented profile types and a Google `installed` desktop-client JSON
document in this version. Reject web/service-account client files. Restrict real token
endpoints and profile-backed API requests to their intended HTTPS origins.

## Native login commands

- `attractor auth login <google-profile>` opens the browser, uses a random-port
  loopback callback with state and PKCE S256, requests offline access and consent,
  exchanges the code once, and persists the refresh token in the OS keychain.
- `attractor auth status [profile]` reports safe profile readiness without a
  token request or browser launch. It distinguishes configured from signed in.
- `attractor auth logout <google-profile>` removes the local refresh grant and
  invalidates in-process tokens for that profile and its dependent providers.
  It does not claim to revoke Google-side consent.

Keychain identity binds the Google client ID and canonical scope set as well as
the profile name. Google login performs one atomic keychain write for the refresh
grant; it skips the separate client-ID entry used by the existing MCP flow.
Changing those settings requires a new login. Validate the
desktop client file's ownership permissions and fixed Google endpoints before
opening the browser. Include the desktop client's secret only in token POST
bodies, never URLs or subprocess arguments. Do not reuse a refresh grant from a
different client/scope identity. Persist a rotated refresh token before returning
new access credentials. Missing scopes, missing refresh token, denied consent,
keychain failure or callback timeout leave no usable partial login. Always close
the callback listener. Headless and unsupported-keychain environments fail with
actionable errors; no token-file fallback is introduced.

## Request behavior

1. An explicitly supplied per-call API key remains an intentional override and
   uses the protocol's API-key presentation. Otherwise a selected credential
   profile takes precedence over environment/file API keys. Providers without a
   profile keep existing behavior. Reject ambiguous combinations of a profile
   with static credential-header/auth overrides.
2. Resolve credentials immediately before each HTTP attempt. Do not capture
   environment keys in client construction when a profile is configured. Model
   discovery, direct adapter calls, completion and streaming use the same seam.
3. Gemini uses a Google access token and the profile's explicit quota-project
   header. Anthropic obtains a Google service-account ID token for audience
   `https://api.anthropic.com`, with email included, then exchanges it for an
   Anthropic bearer token. Both paths keep their existing native API endpoints.
4. Cache short-lived access tokens in memory, keyed by the complete effective
   profile and referenced source. Refresh before expiry with a bounded clock
   margin; concurrent callers share one refresh. Obtain a fresh identity
   assertion for each Anthropic exchange.
5. Missing login, wrong scopes, denied impersonation, rejected federation,
   malformed responses and expired credentials fail with specific safe errors.
   Never fall back to the `.env` key after a selected profile fails. Do not
   automatically replay a potentially accepted inference request after a 401.
6. Status inspection does not obtain tokens or open a browser. Reports identify
   profile type, source, readiness and expiry without token values. Redaction
   covers refresh/access/identity tokens and token-bearing request/response data.

## Setup and verification

Prepare a Google desktop OAuth client and consent with the scopes required for
Gemini and IAM Credentials, then run `attractor auth login google-desktop`.
Confirm the authenticated account and funded Gemini quota project with a minimal
native request. Existing Google CLI/ADC configuration remains independent.

For Anthropic, prepare a dedicated Google service account, the required API and
the narrow ID-token-creation permission on that account. Prepare an Anthropic
service account and federation rule pinned to the Google account's exact numeric
subject, email and audience. Select the funded workspace and inference scope.
Record the concrete resources and grants for review before cloud mutations.

Verification must prove:

- Existing API-key behavior still works and EDN configuration errors are safe.
- Native browser login carries state, PKCE and offline consent; callback
  mismatch, timeout, exchange rejection and keychain failure clean up safely.
  Login and refresh persist only the refresh grant, including rotation; logout
  invalidates dependent in-memory credentials.
- A configured profile defeats a deliberately present stale `.env` key, across
  client construction, direct calls, streaming, retries and model discovery.
- Google refresh, impersonation and Anthropic exchange have correct bodies and
  headers; tokens cannot be sent to a substituted API origin.
- Expiry, concurrent refresh, malformed/failed exchange and profile reload do
  not reuse stale credentials or cross profile boundaries.
- Secret values never enter diagnostic output or stored evidence.
- One native Gemini request and one native Anthropic request succeed using only
  the selected profiles, with API-key headers absent. Controlled protocol tests
  are reported separately if account provisioning still prevents live proof.

Use cheaper subagents for bounded implementation tasks. Run focused auth/provider
tests, impacted adapter tests, compiled CLI checks and the full suite serially.

## References

- [Gemini OAuth setup and quota-project header](https://ai.google.dev/gemini-api/docs/oauth)
- [Google installed-app OAuth and PKCE](https://developers.google.com/identity/protocols/oauth2/native-app)
- [Google service-account ID tokens](https://docs.cloud.google.com/docs/authentication/get-id-token)
- [Anthropic Google federation configuration](https://platform.claude.com/docs/en/manage-claude/wif-providers/gcp)
- [Anthropic exchange, scopes and workspace binding](https://platform.claude.com/docs/en/manage-claude/wif-reference)

## Design checklist

- Context: inspected provider registry, LLM request seams, existing OAuth and MCP refresh.
- Visual companion: not needed for this configuration/protocol decision.
- User scope: local desktop/CLI; both providers; EDN; cheaper implementers.
- Alternatives: user selected native browser login over gcloud bootstrap.
- Design direction: approved by the user's explicit native-login selection.
- Spec review and implementation plan: in progress.

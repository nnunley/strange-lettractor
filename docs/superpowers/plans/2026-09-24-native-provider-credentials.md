# Native Provider Credentials Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Authenticate local Attractor requests to Gemini and Anthropic through native Google browser login, EDN credential profiles, and automatic token refresh/exchange.

**Architecture:** Reuse `attractor.auth` for browser PKCE and keychain storage. Separate credential lifecycle, Google acquisition, and Anthropic federation from the provider registry and LLM adapters. Google client metadata stays in a private file; refresh grants stay in the keychain and short-lived tokens stay in memory.

**Tech Stack:** let-go 1.13, lgx 0.3.2, existing HTTP/JSON/hash/net/os libraries, macOS credential-osxkeychain.

Design: `docs/superpowers/specs/2026-09-24-local-provider-credentials-design.md`.
User selected native browser login explicitly; do not ask again about gcloud.
Existing source/test changes from completed spec work must be preserved. Do not
commit unrelated files or push as part of implementation. All tests are serial;
never launch parallel lgx suites. Use fresh lower-cost workers for bounded tasks.

## Chunk 1: Native OAuth and token lifecycle

### Task 1: Extend existing browser primitives for explicit desktop clients

**Files:** Modify `src/attractor/auth.lg`; extend `test/attractor/auth_test.lg`.

- [ ] Add failing behavioral tests for optional offline consent parameters,
  client-secret token POST, bad token HTTP status, and a login validation hook
  rejecting a partial grant before persistence. Preserve existing MCP tests.
- [ ] Explicitly test `:persist-client-id? false` with a store that fails on a
  second write: native login succeeds with exactly one refresh-grant write;
  existing default MCP behavior still stores both entries.
- [ ] Run `lg -source-paths src:test test/runner.lg attractor.auth-test` and retain RED evidence.
- [ ] Extend `authorization-url` with allowlisted optional `:access-type` and
  `:prompt` fields. Propagate them from the authorization descriptor.
- [ ] Let `exchange-code` accept optional `:client-secret` through opts, adding it
  only to the form body. Require HTTP 200 before accepting a token response;
  include optional response scope and token type in the returned data without changing old
  return fields when absent. No response bodies or exception secrets in errors.
- [ ] Let `authorize` accept `:validate-tokens` callback in options; call it on
  the token result before any persistence. Thread client-secret privately and
  retain existing default behavior when new options are absent. Return scope
  and token type only when supplied. Add `:persist-client-id?` (default true)
  so Google can use one atomic refresh-grant keychain write; its client ID is
  already bound into the keychain identity. Reuse listener cleanup and single exchange.
- [ ] Run auth tests to GREEN, inspect diff and report changed files/evidence.

### Task 2: Reusable credential namespaces

**Files:** Create `src/attractor/credentials.lg`,
`src/attractor/credentials/google.lg`, `src/attractor/credentials/anthropic.lg`;
create `test/attractor/credentials_test.lg` and
`test/attractor/google_credentials_test.lg`.

Public seam (exact spelling can adapt to existing let-go conventions):

```clojure
(credentials/validate-profiles source profiles) ; validated map; no I/O
(credentials/make-resolver profiles options)    ; scoped in-memory state
(credentials/resolve! resolver profile-id)      ; {:token :expires-at-ms :headers}
(credentials/login! resolver profile-id)        ; safe status, no token return
(credentials/status resolver profile-id)        ; no token HTTP/browser requests
(credentials/logout! resolver profile-id)       ; erase grant + invalidate dependents
(credentials/close! resolver)                   ; discard memory-only state
```

- [ ] Write failing tests for profile validation and references, OAuth refresh,
  ID-token acquisition and Anthropic exchange, expiry, concurrent resolution,
  failed/rotated refresh, safe diagnostics and logout invalidation. All external
  services/keychain/browser are injected, with real protocol-shaped responses.
- [ ] Run the two new test namespaces to prove missing behavior.
- [ ] Implement `:google-browser`, `:google-oauth`,
  `:anthropic-google-oidc` profiles exactly as in the design. Enforce the typed
  reference graph: leaf sources point to Google browser profiles. Required IDs,
  scope strings, private client path, quota project, supported fields and types
  are validated with value-free errors. No arbitrary executable EDN.
- [ ] Read only `installed` desktop-client JSON. Require private file mode;
  require client ID/secret and Google authorization/token endpoints (default to
  fixed endpoints if omitted, reject replacements). Do not read global ADC.
- [ ] Use existing `auth/authorize`, store and injected browser opener. Real
  opener uses `open` with an argument vector, not a shell. Login requests offline
  consent and scope string; validate positive expiry, refresh token and granted
  scopes before persistence. Keychain key binds profile/client/canonical scopes.
- [ ] Google login MUST pass `:persist-client-id? false` to `auth/authorize`.
  Confirm its store receives exactly one atomic refresh-grant write. The Google
  client ID is already bound into the keychain identity and private client file.
- [ ] Refresh via `https://oauth2.googleapis.com/token`. Persist rotation before
  returning a new access token. Keychain failure is a safe explicit failure.
- [ ] Mint Anthropic assertions with POST to fixed IAM Credentials origin,
  `projects/-/serviceAccounts/<validated-email>:generateIdToken`, audience
  `https://api.anthropic.com`, `includeEmail: true`. Exchange using the current
  official Anthropic JSON contract at `https://api.anthropic.com/v1/oauth/token`.
  Body includes jwt-bearer grant, assertion, organization, rule, service account,
  workspace. Validate positive lifetime and bearer token type. Request inference
  privileges through the preconfigured rule, not admin privileges.
- [ ] Cache Google and Anthropic access tokens until expiry minus a 30s margin
  (bounded for shorter TTLs); serialize refresh per resolver/profile. Bound
  waiting and transport, always release locks after failure, clear cached state
  on logout/reload. Capture generation before refresh to prevent logout races
  from restoring an erased grant or cached token. No stale-token fallback.
- [ ] Ensure no raw transport exceptions, response bodies or token-bearing data
  escape errors. Redaction must cover current resolved tokens when ordinary
  provider traces/errors are produced. Status must not mint tokens.
- [ ] Run new tests and the existing auth namespace to GREEN, retain evidence.

## Chunk 2: Provider and CLI integration

### Task 3: EDN loading and all native request paths

**Files:** Modify `src/attractor/providers.lg`, `src/attractor/llm.lg`;
extend `test/attractor/providers_test.lg`; create
`test/attractor/provider_credentials_test.lg`.

- [ ] Write RED tests for layered `:credentials`, `:credential_profile`, old
  provider-only parsing, typed references, ambiguous static header rejection,
  stale environment key shadowing, explicit caller key override, and origin
  binding. Include direct calls, client-from-env, models, streaming and retries.
- [ ] Preserve `parse-config`'s provider-map public return; introduce an internal
  document parser for both sections. Validate the merged reference graph after
  layering. Keep existing API-key functions free of network side effects.
- [ ] Registry reload creates/replaces a resolver; expose a safe registry
  credential-profile accessor and resolver accessor for CLI. Preserve lower
  level credential-module independence from providers/LLM/MCP.
- [ ] Introduce one request-auth seam returning headers and private token
  provenance. Profile precedence: explicit caller API key > configured profile
  > legacy environment/file key chain. A selected profile failure never falls
  through. Distinguish keys automatically resolved by client construction from
  caller-supplied keys; do not freeze profile tokens in adapter options.
- [ ] A Google OAuth profile sends Bearer and its explicit x-goog-user-project.
  An Anthropic profile sends Bearer while preserving anthropic-version. Neither
  sends the protocol API-key header. Explicit key override uses API-key headers.
- [ ] Resolve immediately before HTTP attempts and use the same seam for models,
  completion and streaming. Profile-backed target origin is fixed per provider;
  reject base URL overrides to other origins before token acquisition/network.
- [ ] Keep error/evidence redaction safe without initiating credential refresh.
  Update effective provider status to distinguish profile configuration from
  key presence. Client auto-registration includes configured profiles.
- [ ] Run provider credential tests plus existing providers, native adapters,
  signed-history and parity journey tests serially to GREEN.

### Task 4: Native auth CLI and operator documentation

**Files:** Create `src/attractor/cli/auth.lg`; modify
`src/attractor/cli.lg`, `README.md`, `attractor.edn.sample`;
create `test/attractor/auth_cli_test.lg`.

- [ ] Test RED command parsing, safe output/exit statuses and delegation using
  injected resolver operations. No real browser/keychain calls in unit tests.
- [ ] Implement `auth login <google-profile>`, `auth status [profile]`,
  `auth logout <google-profile>` using credentials namespace. Reject missing,
  extra and unknown arguments. Login reports safe completion only; do not print
  access/refresh tokens. Provider display includes selected profile/source.
- [ ] Explain private desktop-client JSON, native browser consent, macOS keychain,
  explicit Gemini quota project, Anthropic external federation prerequisites,
  `.env` precedence, local-only logout and missing external setup. Sample IDs
  are obviously placeholders; sample must not activate unusable profiles by default.
- [ ] Run CLI and impacted config tests; build a fresh unique `/tmp` main binary
  with the existing tiny-tui source path and check auth usage/status/unknown profile.

## Chunk 3: Review, integration and live setup

### Task 5: Review and verify

- [ ] Obtain specification review, repair material issues, then code-quality
  review; keep these scoped to auth changes despite existing dirty files.
- [ ] Run complete focused/impacted namespaces once the source is frozen.
- [ ] Run serial `lgx test`; retain full output. Previous baseline was
  1526 tests / 13863 assertions / zero failures before auth changes.
- [ ] Build a fresh CLI and exercise mock browser callback plus safe CLI status
  through public entrypoints. Re-check `git diff --check`.
- [ ] Update progress with actual implementation/evidence and precise live limits.

### Task 6: Configure and prove the user's accounts

- [ ] Verify the funded Gemini project, Google Desktop OAuth client, and
  Anthropic funded workspace. Do not assume the existing global ADC account,
  quota project, or the billing console's selected project identifies the API key.
- [ ] Prepare exact required Google API/service-account/IAM and Anthropic
  issuer/rule/workspace settings. Present concrete grants before cloud mutation.
- [ ] After required account setup, run native browser login and one low-cost
  request per provider with selected profiles and API-key headers absent.
- [ ] Retain only sanitized status/model/usage proof. If account input or consent
  is unavailable, report live setup pending; do not claim keyless live success.

## Progress

- [x] User chose native browser login for both providers.
- [x] Rechecked repository push status: main ahead 23; implementation batches uncommitted.
- [ ] Spec/plan review.
- [ ] Tasks 1–4 implemented and reviewed.
- [ ] Task 5 integration verification.
- [ ] Task 6 account setup and native proof.

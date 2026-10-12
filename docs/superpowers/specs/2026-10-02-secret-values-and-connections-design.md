# Secret values and authenticated connections

Status: stub, filed 2026-10-02 during the pushback review of the agent context
foundations. Direction agreed; not yet designed.

## Problem

Secrets reach places they should not. Provider keys sit in configuration and in
the process environment as plain strings, so any path that prints or serializes
them — logs, transcripts, error data, state files — can leak them unless every
path remembers to call `providers/redact`. Agents can also read secrets
directly: a tool command can print the environment or read a key file.

## Direction

1. **A secret value type.** A secret is a distinct type whose printed form is
   always redacted (for example `<secret:anthropic>`) through `str`, `pr-str`,
   JSON and EDN encoding. Only the transport that sends the credential reads the
   raw value.
2. **Agents never hold secrets.** A tool that needs a connection — HTTP, a model
   provider, an MCP server — receives an authenticated session or handle from
   attractor. The agent uses the connection; it never sees the credential.
3. **No secrets in model-visible state.** Transcripts, `state.edn` and other
   files a model reads never contain a secret value.

## Starting points

- `providers/redact` (`src/attractor/providers.lg`) and per-entry
  `credential_headers`.
- The execution environment's `:env_policy :none`, which already keeps the
  parent environment out of tool commands.
- The OAuth and keychain work in
  `2026-09-24-local-provider-credentials-design.md`.

## Open questions

- How let-go represents the type so that every printer honours it.
- Which tools need authenticated sessions first, and what a session handle
  exposes to the agent.
- How the agent's working tree and environment are kept free of secret files.
- How the redaction in the context foundations switches to keying off the type.

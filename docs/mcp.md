# MCP tool admission

MCP supports tools that change external state. Attractor defaults to read-only
admission and requires a separate host grant for write-capable tools. Selecting
a server, resolving a project/user manifest conflict, or accepting server tool
annotations does not grant write access.

Declare writes in the server's `mcp.edn` tool entry:

```clojure
{:name "update_issue"
 :description "Update an issue"
 :class :write-tool
 :side-effects :write
 :schema {:type "object"
          :properties {:issue_id {:type "string"}
                       :title {:type "string"}}}}
```

An idempotent tool may also declare `:side-effects :write`; it needs the same
grant. Pure tools and read-only resources cannot declare writes. These are
operator declarations, not a sandbox that detects a server lying about effects.

After reviewing the complete manifest, the host supplies an approval for its
SHA-256 digest and exact, unprefixed tool names:

```clojure
;; Options passed to attractor.agent/make-session:
{:mcp ["issues"]
 :mcp_write_approvals
 {"issues" {:manifest-digest "<SHA-256 of the reviewed mcp.edn text>"
            :tools #{"update_issue"}}}}
```

The digest covers the exact manifest text, including whitespace. Capture it
when reviewing the manifest; do not automatically approve whatever is currently
on disk. `attractor.mcp/find-manifest` exposes `:manifest-digest`; when roots
diverge it reports the project candidate, so review the selected winner's digest
explicitly. Existing `:mcp_approvals` govern project/user root conflicts and
remain separate from write grants.

For `attractor.mcp/admit-servers!` or `attractor.mcp/open-server!`, supply the
same map under `:write-approvals`. Every declared write tool in every selected
server must have a matching grant. Missing grants, changed digests, or unapproved
tool names reject admission before any selected server connection opens. A
grant does not expose undeclared tools. Admission evidence records the admitted
write names alongside the manifest digest.

This is a host API policy. Hosts that require human approval must collect it
before supplying the grant. There is no new interactive CLI approval prompt or
automatic grant from model output. Existing authentication, limits,
cancellation, provenance, and call evidence apply to write tools too.

The protocol itself does not restrict tools to reads, and treats server tool
annotations as untrusted metadata; see the
[MCP tools specification](https://modelcontextprotocol.io/specification/2025-11-25/server/tools).

Deterministic verification on 2026-09-27: **75 tests / 243 assertions, zero
failures or errors** across `mcp_test.lg`, `mcp_client_test.lg` and
`mcp_stdio_test.lg`. These checks cover admission policy and mocked/local
transports; they do not establish the behavior of an external write-capable
server. Full repository integration also passes: `lgx test`, 1566 tests / 14159
assertions, zero failures (exit 0).

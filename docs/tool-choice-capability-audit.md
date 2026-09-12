# Tool-choice capability audit

Unified LLM section 5.3 requires capability inspection and rejection when an
adapter does not support a requested tool-choice mode. `make-adapter` accepted
`:supports_tool_choice`, but the client never invoked it; native adapters also
left that field empty.

Native protocol adapters now advertise support for `auto`, `none`, `required`,
and `named`, with an optional configured predicate override. Client completion
and streaming check the selected adapter's predicate after middleware changes
have been applied. Rejection raises non-retryable `:unsupported-tool-choice`
before invoking the adapter. Custom adapters without a capability predicate
retain their existing behavior.

`tool_choice_capability_contract_test.lg` verifies unsupported choices never
reach an adapter, supported choices are delivered intact, and native adapters
expose their modes. Eight assertions failed before the fix; three tests and ten
assertions pass afterward. Existing LLM tests (83/495), middleware routing tests
(4/6), and the build also pass.

The adjacent definition-time audit found that `make-tool` already validates
identifier syntax, the 64-character limit, and an object-root parameter schema.
This does not establish validation for callers bypassing that constructor with
arbitrary maps, nor a complete live tool-choice matrix.

## Required name for named choices

The shared tool-choice reader now rejects `named` choices whose `tool_name`
is missing, non-string, empty, or whitespace-only. Previously those requests
could reach an adapter with a null or unusable tool name. The error is
non-retryable `:invalid-request`, and validation runs before client dispatch
even when a custom adapter has no capability predicate. Keyword-key and
string-key choice maps remain supported.

Two additional tests exercise completion and streaming rejection plus an intact
valid string-key choice. Sixteen assertions failed before the repair; the
namespace now passes five tests/27 assertions. Existing LLM tests (83/495),
middleware routing tests (4/6), and build pass. These checks validate the
required field, not whether the name matches a declared tool.

# Schema resource and dynamic-reference repair

This continues the full original-spec closure under ULLM-STRUCTURED-01
(unified LLM §§4.5–4.6, §8.4). The prior annotation iteration passes the
integrated 1417-test suite. Known next failure: bundled relative `$id` resources
are unresolved; `$dynamicRef` is ignored, allowing invalid values.

1. Test RFC 3986 URI-reference resolution, then implement a small pure helper.
   The runtime's `io/url` parser has no relative resolver and loses delimiter
   presence, so use a component-preserving parser and the RFC 5.2 algorithm.
2. Index schema resources under their resolved identifiers. Traverse only
   recognized schema locations, not examples/defaults. Preserve lexical base
   URI through nested `$id` and pointer traversal. Keep duplicate-resource
   identifiers deterministic and reject conflicting registrations.
3. Add optional explicit registry/base URI to the validator. Resolve known
   bundled/registered schemas without implicitly downloading identifiers.
   Unknown resources remain validation failures. Carry these options through
   public structured-output helpers so this is usable beyond the validator.
4. Apply both `$ref` and `$dynamicRef`, including siblings. Dynamic lookup
   starts from the static target and overrides only a named dynamic anchor,
   using the outermost matching resource on the immutable evaluation path.
   Do not leak dynamic scope across sibling validations or separate calls.
   Preserve annotation propagation and cycle rejection outside boolean logic.
5. Run existing reference/anchor/recursion/schema tests; both structured APIs;
   official draft2020-12 ref/dynamicRef/unevaluated corpora with explicit
   fixture resources; then full lgx 0.3.2 suite and compiled CLI checks.

Dialect dispatch, meta-validation and remaining original-spec work stay open;
this iteration does not claim complete JSON Schema conformance.

References: [JSON Schema core §§8.2.3 and 9.2](https://json-schema.org/draft/2020-12/json-schema-core),
[RFC 3986 §5.2](https://www.rfc-editor.org/rfc/rfc3986#section-5.2).

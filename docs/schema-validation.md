# Structured-output schema validation

`attractor.llm/validate-json-schema` returns `[valid? reason]`. `generate-object`
and `stream-object` use the same validator on the final parsed JSON and raise
`:no-object-generated` when it is invalid. Partial stream values are provisional.

The validator supports the published JSON Schema draft 2020-12 dialect and
registered custom 2020-12 dialects. Declare one with `$schema` at a resource
root, or set `:schema_default_dialect` to a dialect URI for resources without a
declaration. A root document in `:schema_registry` chooses its own dialect;
embedded `$id` resources inherit their enclosing dialect unless they declare
another. A `$schema` inside an ordinary subschema is invalid. Unsupported
historical drafts, unavailable dialect URIs, malformed vocabulary declarations,
and unknown required vocabularies return `[false reason]`.

A registered custom meta-schema must itself declare the canonical draft 2020-12
`$schema`, and a present `$vocabulary` must include the 2020-12 core vocabulary
with `true`. Custom ancestry chains and unrecognized required vocabularies are
unsupported. Vocabulary URI keys must be absolute and normalized. An optional
flag does not disable a recognized vocabulary. Custom dialects must be supplied
through `:schema_registry` (including embedded resources in a registered
document); an embedded meta-schema in the input schema alone does not register
its dialect. Bundled published meta-schemas take precedence over registry
documents claiming those identities during schema validation.

An undeclared schema uses compatibility mode. It retains valid legacy tuple
`items` and `dependencies` behavior, while checking keyword shapes before
instance evaluation. This mode does not claim conformance to a historical draft.
Explicit draft 2020-12 treats `dependencies` and `additionalItems` as deprecated,
non-asserting keywords. Registered dialects select assertions through their
`$vocabulary` map; known optional vocabularies remain active, and unknown
optional vocabularies are ignored. `format` and `content*` remain annotations.
Regular-expression syntax follows the runtime regex engine; optional ECMA
regex conformance cases are outside the mandatory corpus coverage.

Every schema resource is checked against its own trusted or registered
meta-schema before instance evaluation, including schema branches that the
instance would not visit. The published meta-schemas are bundled in the
application; validation never downloads an identifier. An invalid schema
returns `[false reason]`. Both structured output APIs turn that into a
`:no-object-generated` error after receiving final JSON.

The validator supports local JSON Pointers and named anchors, bundled resources
identified by `$id`, and draft 2020-12 `$dynamicRef`/`$dynamicAnchor` evaluation.
Relative identifiers follow RFC 3986. `$ref` and `$dynamicRef` apply alongside
their sibling constraints. Successful references contribute annotations to
`unevaluatedProperties` and `unevaluatedItems`.

Pass external resources explicitly; identifiers never trigger network requests:

```clojure
(require '[attractor.llm :as llm])

(def validation-options
  {:schema_base_uri "https://example.org/schemas/output"
   :schema_default_dialect "https://json-schema.org/draft/2020-12/schema"
   :schema_registry
   {"https://example.org/types/positive" {:type "integer" :minimum 1}}})

(llm/validate-json-schema 3 {:$ref "../types/positive"} validation-options)
;; => [true ""]

(llm/validate-json-schema 0 {:$ref "../types/positive"} validation-options)
;; => [false "Number is below minimum 1"]
```

The same options are accepted in the options maps of `generate-object` and
`stream-object`. They configure local validation and are removed from provider
requests. The output schema itself is sent unchanged; the selected provider
must also accept it. Keyword values such as `:type :integer` remain accepted
by the local API without changing the provider payload.

Without a retrieval URI, an anonymous schema uses
`https://attractor.invalid/schema` as its base. An absolute root `$id` overrides
that base. Registry keys name retrieval URIs; a registered schema's own `$id`
also identifies it. Conflicting documents with the same resource identifier
are rejected. Only recognized schema locations declare embedded resources;
objects inside examples, defaults, or unknown keywords are not indexed.

An evaluated unresolved reference or a non-progressing reference cycle is a
validation failure, including inside `not`, `anyOf`, and `if`. A reference in an
unevaluated conditional branch does not need to resolve. Recursive schemas can
validate finite nested instances; sibling evaluations and separate calls have
independent reference scope.

The vendored mandatory draft 2020-12 suite runs all 1,301 cases from 46
upstream files, alongside focused schema-document and structured API contract
tests. Optional upstream tests are outside this coverage statement.

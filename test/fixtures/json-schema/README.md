# JSON Schema fixtures

`mandatory2020-12/` holds the single pinned copy of the upstream test corpus
and remote resources from [JSON-Schema-Test-Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite/tree/5b0ee1613e45fcc2bddac00e07c19cd49b00d8a8),
commit `5b0ee1613e45fcc2bddac00e07c19cd49b00d8a8`. Upstream's MIT license is
included in `LICENSE`. See `mandatory2020-12/README.md` for the full corpus.

Both official test runners use `attractor.schema-official-fixtures` to load
these files and check examples, while retaining separate registry policies
and dialect modes:

- `attractor.schema-official-reference-test` runs all 323 cases in four groups
  without an explicit default dialect: 79 ref, 44 dynamicRef,
  129 unevaluatedProperties, and 71 unevaluatedItems. Its registry always
  supplies three remote resources and the eight published meta-schemas.
- `attractor.schema-official-dialect-test` runs all 1,301 mandatory cases with
  an explicit 2020-12 default dialect and each group's manifest registry. It
  supplies trusted meta-schemas only when referenced. The 323 reference cases
  intentionally run again under this different contract.

`meta/` contains the published [2020-12 meta-schema](https://json-schema.org/draft/2020-12/schema)
and its seven vocabulary meta-schemas, downloaded 2026-09-23. These independent
test resources remain separate from the runtime's embedded trusted schemas:
they are supplied through an explicit registry, never fetched by validation.

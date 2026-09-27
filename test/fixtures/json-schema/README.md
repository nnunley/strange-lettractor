# JSON Schema reference fixtures

The four draft2020-12 test groups and their three remote resources are copied
unchanged from [JSON-Schema-Test-Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite/tree/5b0ee1613e45fcc2bddac00e07c19cd49b00d8a8),
commit `5b0ee1613e45fcc2bddac00e07c19cd49b00d8a8`. Upstream's MIT license is
included in `LICENSE`.

`meta/` contains the published [2020-12 meta-schema](https://json-schema.org/draft/2020-12/schema)
and its seven vocabulary meta-schemas, downloaded 2026-09-23. They are test
resources supplied through an explicit registry, never fetched by validation.

`attractor.schema-official-reference-test` runs all 323 cases in the four
groups without exclusions: 79 ref, 44 dynamicRef, 129 unevaluatedProperties,
71 unevaluatedItems. These groups do not establish whole-dialect conformance.

# Mandatory draft 2020-12 conformance corpus

The 46 test files in `tests/` and 19 referenced files in `remotes/` come from
[JSON-Schema-Test-Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite/tree/5b0ee1613e45fcc2bddac00e07c19cd49b00d8a8),
commit `5b0ee1613e45fcc2bddac00e07c19cd49b00d8a8`. `LICENSE` is the upstream
MIT license. The files are copied without changing their test content.

`registries.json` records the transitive remote URI closure for each group in
each file, in upstream order. The regression test runs every group and case,
with `:schema_default_dialect` set to draft 2020-12. Published meta-schemas are
added only when a schema or its remote resources reference them. No optional
test files or cases are counted as mandatory coverage.

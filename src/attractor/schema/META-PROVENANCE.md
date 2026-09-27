# Bundled JSON Schema meta-schemas

`trusted_metas.lg` embeds the published JSON Schema draft 2020-12 main
meta-schema and seven vocabulary meta-schemas from
`https://json-schema.org/draft/2020-12/schema` and
`https://json-schema.org/draft/2020-12/meta/{core,applicator,unevaluated,validation,meta-data,format-annotation,content}`.
The JSON documents were retrieved on 2026-09-23 and are also preserved in
`test/fixtures/json-schema/meta/`. The embedded JSON is parsed once when the
namespace loads, so a compiled binary needs neither fixture files nor a
network connection to validate schemas. `META-LICENSE` reproduces the upstream
[JSON Schema specification license](https://github.com/json-schema-org/json-schema-spec/blob/main/LICENSE).

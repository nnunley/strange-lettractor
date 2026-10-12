# Schema dialect closure

Read-only scope audit and root verification, 2026-09-23. The validator currently
ignores `$schema` and evaluates a union of keywords. Reference/unevaluated
conformance does not establish dialect conformance.

Reproduced through public `validate-json-schema`:

| Declaration and schema | Instance | Current | Required |
|---|---|---|---|
| 2020-12, `type: "strng"` | `5` | valid | invalid schema |
| draft-04, `minimum: 2`, `exclusiveMinimum: true` | `2` | valid | invalid instance |
| draft-07, `$ref` to object definition, sibling `type: "string"` | `{"a": 1}` | invalid instance | valid instance; legacy `$ref` ignores siblings |

The scope reviewer also confirmed that unknown `$schema` declarations are
silently ignored and draft-2020-12 accepts legacy tuple `items`, which is invalid
in that dialect. Existing undeclared-schema tests intentionally use legacy
tuple items and definitions; preserve that compatibility path explicitly.

The original specification requires schema validation but names no draft and
does not require every historical dialect. A coherent, documented dialect
contract is required; recognizing a declaration while applying another draft's
rules is incorrect. Preserve existing undeclared compatibility behavior.

Next implementation task, using a cheaper implementation subagent:

1. Explicit draft2020-12 dispatch plus schema validation. Select the actual
   vocabulary semantics, reject invalid keyword shapes/types, and validate
   declared dialect URIs. Use bundled/registered meta-schemas without network
   fetching. Avoid recursive meta-validation of the trusted meta-schema itself.
   Invalid or unsupported declarations must not silently report success.
Potential follow-on compatibility work, only if included in the declared
support contract (not additional original-spec requirements):

- Draft2019-09 semantics, including recursive references and vocabulary rules.
- Draft-07/06 semantics, including ignored `$ref` siblings and keyword-era
   distinctions. Their exclusive bounds are numbers, so booleans are invalid
   schemas instead of draft-04 strict-bound flags.
- Draft-04 semantics, including `id`, fragment identifiers, boolean exclusive
   bounds, legacy tuple arrays, and object-only schemas.

Rejecting unsupported declared drafts must be documented as unsupported, never
reported as implemented semantics. Keep the story partial until the selected
contract has adequate official corpus and public structured-API proof.
Keep schemas sent to providers unchanged and document the local dialect API.

Likely code boundaries: dialect/meta-schema helpers under `attractor.schema`,
evaluation dispatch in `llm.lg`, resource indexing carrying resource-local
dialect/base information. New proof seams must include both structured APIs,
invalid schema failures outside boolean logic, nested resource declarations,
legacy-default regressions, and official per-dialect fixtures.

## Contract decisions for the implementation brief

- Support explicit `https://json-schema.org/draft/2020-12/schema` (and its
  empty-fragment spelling). Support explicitly registered 2020-12 custom
  meta-schemas with recognized vocabulary declarations; unrecognized required
  vocabularies fail, optional unknown ones are ignored. Unsupported declared
  drafts or unavailable dialect URIs produce an explicit validation failure.
  No declaration selects the documented
  compatibility mode, preserving valid legacy tuple items and dependencies;
  compatibility is not a claim to implement historical drafts.
- Explicit custom-meta registration uses `:schema_registry`, including active
  embedded resources within its documents. A meta-schema appearing only in
  the main input is not automatically registered; callers can register it
  explicitly. Review adjudication retains this bounded registration API rather
  than adding another discovery source. Bundled trusted meta-schema identities
  remain authoritative during schema preflight; registry overrides cannot
  weaken their constraints.
- Add local `:schema_default_dialect` (URI string) to select 2020-12 for schemas
  without declarations, including independent registry documents. Explicit
  declarations win; embedded resources inherit their enclosing dialect. Both
  structured APIs pass this option to local validation and strip it from
  provider requests. This avoids adding provider-visible `$schema` fields.
- Validate schema keyword shapes before instance evaluation, including invalid
  schemas hidden in unused applicators. Preserve the public `[valid? reason]`
  result and both structured APIs' `:no-object-generated` failure contract.
  Undeclared compatibility must preserve valid old forms, not silently accept
  misspelled types or malformed constraints.
- Dialect belongs to a schema resource: embedded resources inherit it unless
  they declare their own. A `$schema` declaration on a non-resource subschema
  is invalid. External registry documents have their own resource/default
  dialect; reference traversal must carry it with base URI and dynamic scope.
- In explicit 2020-12 evaluation, legacy `dependencies` and `additionalItems`
  do not become assertions. The published meta-schema still constrains some
  deprecated keyword shapes. Unknown annotation data must not introduce
  resources or declarations. `format` and `content*` are annotations, not
  optional format/content assertion support.
- Select active keyword vocabularies from the resource's declared meta-schema.
  A custom dialect containing core/applicator but no validation vocabulary
  still applies `properties` and boolean schemas, but must ignore `minimum`
  and other absent validation assertions. Do not confuse a vocabulary's
  required/optional flag with enabling/disabling a known vocabulary.
- Bundle trusted meta-schemas for standalone binaries; production validation
  must not read `test/fixtures` or fetch schemas from the network. Preserve
  upstream license/attribution when copying the published documents. Trusted
  meta-validation must not recursively invoke the public schema preflight.
- Compound resources may have different dialects. Validate them under their
  own contracts rather than accidentally applying the enclosing meta-schema
  to all embedded data. Keep provider payload schemas unchanged.

Primary references checked 2026-09-23: [2020-12 core §§8.1.1, 9.3.2–9.3.3](https://json-schema.org/draft/2020-12/json-schema-core),
[validation §7.2](https://json-schema.org/draft/2020-12/json-schema-validation),
and the [upstream license](https://github.com/json-schema-org/json-schema-spec/blob/main/LICENSE).

## Broader current-state evidence

Root downloaded the same pinned official corpus revision used by ITER-0015,
`5b0ee1613e45fcc2bddac00e07c19cd49b00d8a8`, into `/tmp` and ran all 46 mandatory
draft2020-12 groups/files (384 groups, 1301 cases). Each group gets an explicit
registry containing its transitive `$ref`/`$dynamicRef`/`$schema` resources.
Current evaluator: **1300 pass, 1 fails**. The failure is
`vocabulary.json / schema that uses custom metaschema with with no validation
vocabulary / no validation: invalid number, but it still validates`:
`minimum: 10` incorrectly rejects `1` under the core/applicator-only dialect.
No cases were excluded. This does not prove dialect or invalid-schema support,
because the current evaluator ignores declarations.

Audit script/input/result:
`/tmp/attractor-schema-official-audit-20260923.lg`,
`/tmp/attractor-schema-corpus-input-20260923.json`,
`/tmp/attractor-schema-official-audit-20260923.edn`.
For final regression evidence, vendor the required official files/remotes with
provenance and run the complete mandatory corpus using `:schema_default_dialect`
2020-12. Add independent invalid-schema, unsupported-dialect, resource inheritance,
required/optional vocabulary and structured-API contract tests; corpus success
alone is not evidence for those additional guarantees.

The existing evaluator successfully evaluates the bundled published meta-schema
against representative schema documents: misspelled type, negative `minLength`,
string-valued `required`, 2020-12 tuple `items`, and an invalid unused `anyOf`
branch are rejected; a valid object schema passes. Probe:
`/tmp/attractor-schema-meta-preflight-probe-20260923.lg`. Reuse this evaluator
behind a trusted internal entry point rather than introducing another schema
engine; preserve resource-specific preflight for compound dialects.

## Outcome — ITER-0018, 2026-09-23

Implemented by gpt-6-sol, with a bounded gpt-6-luna fixture alignment after the
first integrated run. Paired spec and quality reviews approve both changes.
Repairs from review cover registry base resolution, active embedded meta-schema
discovery, inactive annotation isolation, unused reference URI syntax, explicit
legacy nulls, and trusted meta-schema precedence. The registered custom-meta
boundary remains explicit; main-input-only definitions are not auto-registered.

Focused dialect contracts pass 20 tests / 88 assertions. All 46 pinned official
mandatory files (384 groups / 1301 cases) pass without exclusions; their bytes
match upstream. The first integration had 12 older fixture failures because
meta-validation now rejects raw arrays under `$defs` and malformed percent URI
escapes fail earlier. The fixture-only repair uses valid `anyOf` array locations,
preserves pointer index/escape rejection and explicitly rejects the old invalid
schema. Root focused verification passes 108 tests / 616 assertions.

Final `lgx test` on lgx 0.3.2: **1481 tests / 13376 assertions / zero failures**,
exit 0, `/tmp/attractor-schema-dialect-integrated-20260923.log`. The initial
failure log remains `/tmp/attractor-schema-dialect-initial-failures-20260923.log`.
Six fresh standalone compiled validation probes pass from `/tmp`; a fresh
compiled CLI validates `examples/hello.dot` with no diagnostics. Full evidence
paths are in `spec-closure.md`. Historical drafts, optional format/content
assertions and runtime-external regular-expression dialects are not claimed.

Nonblocking maintenance observation: schema-location keyword lists in dialect
and resource modules must stay synchronized when adding vocabulary support.
No fixed discovered-test-count assertion was added, following the user's
existing preference; corpus file inventory and upstream provenance are checked.

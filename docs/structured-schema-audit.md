# Structured-output schema audit

Unified LLM sections 4.5 and 4.6 require final structured outputs to be validated.
The local validator ignored `patternProperties`. That accepted invalid values
under matching keys and, when `additionalProperties` was false, rejected valid
keys that should have been admitted by a pattern.

The object validator now checks every matching pattern schema, alongside any
explicit property schema, and excludes pattern-matched keys from additional
properties. Matching is unanchored unless the schema provides anchors. Boolean
schemas and local references use the existing recursive validator. Semantics
follow the [JSON Schema object reference](https://json-schema.org/understanding-json-schema/reference/object#patternProperties).

`pattern_properties_contract_test.lg` covers matching and extra keys, overlapping
patterns, explicit properties, boolean rejection, local references, and a public
`generate-object` failure for invalid model output. Eight assertions failed
before the change; four tests/11 assertions pass afterward. Existing LLM tests
(83/495), structured-stream tests (4/9), and build pass.

This repairs one missing keyword, not complete JSON Schema dialect conformance.
The implementation uses the runtime's regular-expression engine; full ECMA-262
regex compatibility is not established. Other dialect keywords and recursive
reference termination still need assessment. Partial-object display filtering
is separate from final validation and is not expanded by this change.

## Conditional schemas

The validator also ignored `if`/`then`/`else`, allowing final objects to omit
fields required by the selected branch. It now validates `if` against the
instance, applies only the selected `then` or `else` schema, and treats an
omitted branch as unconstrained. Without `if`, standalone `then` and `else`
remain ignored. Boolean schemas and string-key schemas are supported.
These rules follow the [JSON Schema conditional reference](https://json-schema.org/understanding-json-schema/reference/conditionals#if-then-else).

`conditional_schema_contract_test.lg` exercises discriminator-dependent required
fields, missing branches, false schemas, and final streamed-object rejection.
Seven assertions failed before the fix; three tests/13 assertions pass afterward.
Pattern-property (4/11), LLM (83/495), structured-stream (4/9), and build checks
also pass. This adds conditional branch validation, not a claim that every
JSON Schema keyword is implemented.

## Property dependencies

The object validator now enforces `dependentRequired`, `dependentSchemas`, and
the older `dependencies` form. Array dependencies extend required properties;
schema dependencies validate the whole instance, independently of its ordinary
property constraints. A triggering property is tested for presence, so false
and null values still activate dependencies. Dependencies remain directional.
The [conditional reference](https://json-schema.org/understanding-json-schema/reference/conditionals)
documents both modern keywords and their legacy form.

`schema_dependencies_contract_test.lg` covers absent, false, null, and true
triggers; required-property presence; whole-object schema validation; boolean
rejection; and local references. Twelve assertions failed before the change;
three tests/26 assertions pass afterward. Conditional-schema (3/13),
pattern-property (4/11), LLM (83/495), and build checks also pass.

## Array gaps reproduced after the object-schema repairs

A native let-go probe of `validate-json-schema` produced these results:

| Instance | Schema | Observed | Required |
| --- | --- | --- | --- |
| `["wrong"]` | `{"type":"array","contains":{"type":"integer"}}` | Valid | Invalid: no matching item |
| `["wrong"]` | `{"type":"array","prefixItems":[{"type":"integer"}]}` | Valid | Invalid: first item has wrong type |
| `[1]` | `{"type":"array","items":[{"type":"integer"}]}` | Invalid: schema must be object or boolean | Valid under legacy tuple syntax |

The [JSON Schema array reference](https://json-schema.org/understanding-json-schema/reference/array)
describes these constraints and the draft-specific tuple forms. Source inspection
confirms the current array validator supports cardinality, uniqueness, and a
single repeated `items` schema, but not tuple positions or containment. These
are reproduced implementation gaps, not credential-dependent live-test gaps.
The next array work must also cover bounds on matching items and constraints
on items beyond a tuple's prefix. Dialect selection and unevaluated-item
tracking remain separate unresolved questions.

Integrated verification after the default-client and object-schema repairs:
`make test` exited 0 with 1096 tests, 9976 assertions, and zero failures.
Log: `/tmp/attractor-shared-transport-suite.log`. This result confirms the
current regression suite passes while the array gaps above remain reproduced.
ULLM-STRUCTURED-01 is therefore marked partial in the requirement ledger.

## Array constraints repaired

The reproduced array gaps above are now fixed. `prefixItems` validates each
present position; modern `items` constrains only the tail. Legacy array-valued
`items` supplies the positions and `additionalItems` constrains its tail.
Unspecified tail schemas allow additional values, and missing prefix positions
do not imply a minimum array length. Ordinary schema-valued `items` continues
to validate every item and ignores legacy `additionalItems`.

`contains` now requires a matching item by default, with `minContains` and
`maxContains` applying to the matching subset. A zero minimum permits no
matches, including with `contains: false`. Bounds without `contains` are ignored.

`array_schema_contract_test.lg` covers positions, tails, ordinary items,
containment bounds, and boolean schemas. Thirteen assertions failed before the
repair; four tests/32 assertions pass afterward. LLM (83/495), structured-stream
(4/9), and build checks pass. The full-suite result above predates this repair.
Dialect selection, unevaluated annotations, and remaining keywords still require
assessment, so the structured-output ledger stays partial.

## JSON equality

`enum`, `const`, and `uniqueItems` previously used host-language equality,
which distinguishes integer `1` from decimal `1.0`. JSON Schema requires
numerically equal values to compare equal, including within arrays and objects
([instance equality](https://json-schema.org/draft/2020-12/json-schema-core#section-4.2.2)).
These constraints now share a recursive comparison representation that normalizes
integral numbers to exact big integers. Large integers are not first rounded
through floating point. Validation does not mutate the original values.

`schema_equality_contract_test.lg` checks primitive and nested equivalence,
duplicate array values, array order, type distinctions, and adjacent large
integer/decimal values beyond double's exact integer range. Six assertions
failed before the fix; two tests/17 assertions pass afterward. Array tests
(4/32), LLM tests (83/495), and build pass. This does not restore precision
already lost by a JSON decoder or establish arbitrary-precision decimal parsing.

## Property names

`propertyNames` previously had no effect. The object validator now applies its
subschema to each key independently of the associated value, following the
[property-name contract](https://json-schema.org/understanding-json-schema/reference/object#property-names).
Boolean schemas and local references retain their usual semantics; an empty
object satisfies even `propertyNames: false` because it has no keys to reject.

Five assertions failed before the repair. The property/pattern namespace now
passes six tests/19 assertions, covering invalid patterns, short and empty keys,
empty objects, boolean rejection, and local references. LLM (83/495), dependency
(3/26), conditional (3/13), array (4/32), and equality (2/17) tests pass, as do
the build and whitespace check. The full-suite result above predates this repair.
Dialect selection and unevaluated annotation tracking remain unresolved.

## Array indices in local references

The reference audit confirms that both a referenced schema and its sibling
constraints apply. It also reproduced invalid array-index handling: `00` and
`01` resolved successfully, and an oversized decimal index threw instead of
returning an unresolved-reference result. The resolver now requires canonical
array indices and handles numeric overflow as an unresolved reference, following
[RFC 6901 section 4](https://www.rfc-editor.org/rfc/rfc6901.html#section-4).
Object keys such as `01` retain their literal meaning.

`schema_reference_contract_test.lg` passes two tests/12 assertions after three
assertions failed before the fix. The LLM namespace initially reported two
failures in existing timeout tests (idle-stream cleanup after a fixed 25 ms
sleep, and an exact attempt count under a 10 ms total deadline). An unchanged
rerun passed 83 tests/495 assertions and the build passed. This is evidence of
intermittent failures requiring investigation, not proof of reliable deadline
tests. Logs: `/tmp/attractor-schema-reference-checks.log` and
`/tmp/attractor-schema-reference-recheck.log`. Full-suite verification has not
been rerun for this change. URI fragment decoding and cyclic references remain
outside this evidence.

## Timeout evidence follow-up

The two intermittent assertions above relied on scheduling within very small
windows. Idle cleanup now delivers a promise from the registered close callback;
the test waits for that callback before demanding any more stream events. It
therefore checks autonomous cleanup rather than assuming a 25 ms sleep was
sufficient. The stream uses a 500 ms deadline and a bounded two-second observation.

The retry-delay test now observes the actual retry callback and its five-second
delay following a rate-limit failure. It requires total timeout to return within
two seconds under a 500 ms deadline. This proves the retry path was reached and
its delay interrupted; an adapter-attempt counter alone could not establish that.
Production timeout code is unchanged. The focused LLM namespace passes 83 tests
and 496 assertions. These tests still require scheduling within their bounded
observation windows; they do not establish hard real-time guarantees.

Integrated verification after the array, equality, property-name, reference-index,
and timeout-test changes: `make test` exited 0 with 1106 tests, 10046 assertions,
and zero failures. Log: `/tmp/attractor-shared-transport-suite.log`. This supersedes
the earlier regression-run totals, not the unresolved conformance findings.

## URI fragment references

Local `$ref` fragments now undergo percent decoding before JSON Pointer
tokenization, as required by [RFC 6901 section 6](https://www.rfc-editor.org/rfc/rfc6901.html#section-6).
This handles UTF-8 names, encoded separators, literal percent signs and encoded
tilde escapes. Literal plus signs remain plus signs. The existing let-go
`io/decode :url` primitive uses query decoding, so literal `+` is protected before
that call. Percent decoding happens once; `%2520` names a literal `%20` key.
Malformed percent escapes and invalid pointer tilde escapes return unresolved
references rather than matching identically spelled object keys.

Eleven assertions failed before the repair. Reference tests now pass four tests
and 27 assertions, including empty names and `~01` escape ordering. LLM tests
(83/496), build, and whitespace checks pass. The full-suite result above predates
this change. Named anchors, dynamic references, resource scope changes via `$id`,
and cyclic-reference termination remain outside this evidence.

## Recursive reference termination

The validator followed local references without tracking active evaluations.
The new cyclic-schema namespace did not terminate against the old implementation;
the direct native runtime probe had to be stopped (exit 137). Its requested
five-second SIGALRM did not stop the runtime, so that alarm is not evidence of
a reliable deadline. The probe process was identified and explicitly killed.

Reference evaluation now carries an immutable set of active reference/value
pairs within each validation call. Re-entering the same pair aborts validation
with a cyclic-reference diagnostic. That error bypasses applicator boolean logic
and is converted to the public invalid result only at the outer boundary, so
`not` cannot turn the cycle into success. Descending into a finite tree and
reusing the same reference on equal sibling values remain valid. Unvisited
cycles in definitions, absent properties, or unselected branches are ignored.
This follows [JSON Schema core section 9.4.1](https://json-schema.org/draft/2020-12/json-schema-core#section-9.4.1),
which forbids infinite validation loops and leaves cyclic-schema results undefined.

`schema_recursion_contract_test.lg` passes 4 tests/22 assertions, including
completion and streaming object generation reporting `no-object-generated`.
Reference (4/27), array (4/32), conditional (3/13), LLM (83/496), structured-stream
(4/9), build, and whitespace checks pass.
Log: `/tmp/attractor-schema-recursion-checks.log`.
This addresses local-reference cycles; named anchors, dynamic references,
resource scope, full dialect conformance, and deep finite-input stack bounds
remain outside this evidence.

## Exact numeric multiples

`multipleOf` previously converted both operands to double and accepted quotients
near an integer using a tolerance. That accepted `0.1000000000000001` as a
multiple of `0.1`, erased odd parity above double's exact integer range, and
accepted tiny nonzero quotients near zero. Double overflow also rejected valid
large quotients. These violate the integer-quotient rule in
[JSON Schema validation section 6.2.1](https://json-schema.org/draft/2020-12/json-schema-validation#section-6.2.1).

The validator now uses native let-go `rationalize` on each operand and requires
their exact quotient to be an integer. The primitive preserves integer values
and uses the shortest decimal representation for floats, so `0.3` remains a
multiple of `0.1` without rounding a nearby different value into acceptance.
Non-finite numeric inputs cannot be rationalized and fail this constraint.

Ten assertions failed before repair. `numeric_schema_contract_test.lg` passes
4 tests/20 assertions after it, covering near-misses, negative instances, zero,
large integers, extreme scales, invalid divisors, and rejection through both
completion and streaming object generation. Equality tests (2/17), LLM tests
(83/496), structured-stream tests (4/9), build, and whitespace checks pass.
Log: `/tmp/attractor-numeric-schema-checks.log`.

This removes arithmetic approximation within this constraint; it cannot recover
precision already lost while decoding JSON. Arbitrary-precision JSON decoding
and complete schema meta-validation remain separate gaps. The integrated
1141/10264 suite result above predates this focused repair.

Integrated verification after the recursion guard: `make test` exited 0 with
1141 tests, 10264 assertions, and zero failures.
Log: `/tmp/attractor-recursion-integration-suite.log`.
A focused independent review found no blocking correctness issues in the guard
or omitted-model routing; it did not claim exhaustive schema or provider coverage.

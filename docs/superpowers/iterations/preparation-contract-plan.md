# Preparation contract repairs

Scope audit, 2026-09-23: three bounded original-spec gaps remain in parsing
and validation. Implement after the current runtime repair is integrated.
Use `gpt-6-luna` with a short task brief, red/green public contract tests, and
targeted parser/stylesheet/validation/lifecycle verification.

1. **DOT BareValue (§2.2):** the grammar permits hyphens after the first
   character. `llm_model=claude-sonnet-4-5` currently fails because the tokenizer
   stops at an internal hyphen. Accept the specified attribute value grammar
   while retaining strict node identifiers, negative numbers, directed `->`
   tokenization without whitespace, and rejection of undirected `--` edges.
2. **Stylesheet reasoning values (§8.4):** `reasoning_effort: extreme` currently
   parses and is applied. Recognized values are `low`, `medium`, and `high`.
   Invalid declarations must produce the existing stylesheet diagnostic and
   must not partially apply the stylesheet. Preserve custom properties and
   selector/cascade behavior; do not add unrelated provider restrictions.
3. **Custom lint objects (§§7.3–7.4):** a map implementing `:name` and `:apply`
   is currently called as a lookup function, silently yielding no diagnostics.
   Support that interface alongside existing function rules. Preserve rule
   order and complete diagnostic aggregation. Invalid rule objects should
   fail explicitly. Verify through public validation and pipeline preparation,
   including an error that prevents execution before any handler/event.

These repairs do not include module extraction or new application features.
Record focused proof in the behavior corpus and iteration log after review;
retain full-suite evidence separately from isolated contracts.

## Implementation and review evidence (2026-09-23)

Implemented by `gpt-6-luna`, with root integration and independent paired spec
and quality reviews. All reviewers approve the final scoped source/test changes.

| Contract | Public proof |
|---|---|
| BareValue and strict name contexts | `parse-dot`: model names, trailing/repeated hyphens, negative numbers, duration tokens, adjacent arrows, invalid node/attribute names, qualified keys and quoted custom properties |
| Reasoning enum and atomic stylesheet rejection | `parse-stylesheet`, syntax diagnostics and `pipeline/prepare`: all three accepted values, bare/quoted spellings, invalid stylesheet with no partially applied model/custom property |
| Rule object/function compatibility | `validation/validate`: named map rules, functions, Vars, ordered diagnostics, explicit rejection of malformed maps and callable data |
| Error gate before effects | `pipeline/prepare` and `pipeline/run`: diagnostics retained; no handler, lifecycle callback, event or log-directory creation after a custom-rule error |

Initial red/green checks exposed the original gaps. Root/review counterexamples
then exposed duration/trailing-hyphen, Var-callability and hyphenated-key
regressions; each gained permanent public regression coverage before repair.
Final contract tests: **7 tests / 50 assertions / zero failures**. Fresh root
parser/style/validation/lifecycle run: **40 tests / 327 assertions / zero
failures**, exit 0, `/tmp/attractor-preparation-reviewed-20260923.log`.
The fresh standalone CLI `/tmp/attractor-preparation-cli-20260923` validates
`examples/hello.dot` (5 nodes, 4 edges, zero diagnostics). Full suite evidence
is recorded separately in the closure/progress documents after completion.

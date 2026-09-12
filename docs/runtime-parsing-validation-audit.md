# Parsing and validation audit — 2026-09-12

Scope: pinned Attractor §§11.1, 11.2, 11.10. Evidence below was read from source
and test bodies, then the relevant suites were run. This covers these checklist
sections at the parser/validation/preparation seam, not full runtime completion.

| Checklist item | Inspected evidence and finding |
|---|---|
| 11.1 attribute blocks | Parser linear/chaining tests and parity cases 1–3 exercise graph, node and edge blocks. |
| 11.1 graph goal/label/stylesheet | Parity cases 2/18 and lifecycle preparation test check values through parsing and transformation. |
| 11.1 multiline node attributes | Parity case 3 checks multiline prompt and label. |
| 11.1 edge label/condition/weight | Edge construction, parity routing cases and scoped-edge regression check fields used by routing. |
| 11.1 chained edges | Parser chaining test checks endpoints and weights on both resulting edges. |
| 11.1 scoped defaults | Node inheritance/restoration tests and new scoped-edge regression. Edge leakage fixed below. |
| 11.1 flattened subgraphs | Parser subgraph test and lifecycle class-derivation test check retained nodes and derived classes. Subgraph metadata also remains available. |
| 11.1 node classes | Lifecycle preparation and stylesheet specificity tests exercise class-based resolution. |
| 11.1 quoted/unquoted values | Linear parser and quoted typed-attribute tests check strings, integers and Booleans. |
| 11.1 comments | Parser fixtures accept both comment forms; `comments-do-not-consume-quoted-prompt-or-edge-text` preserves URL/comment text inside strings while excluding commented declarations from the graph. |
| 11.2 exactly one start | Valid/missing-start tests plus `boundary-identifiers-and-shapes-require-exactly-one-node` cover identifier fallback, shape-based boundaries, duplicate shapes, and a named start competing with another start-shaped node. Duplicate cases raise validation errors. |
| 11.2 exactly one exit | The same boundary test covers named exits, shape-based exits, duplicate shapes and identifier/shape competition, with error-severity terminal diagnostics. |
| 11.2 no incoming start edges | Lifecycle validation fixture includes `exit -> start` and requires `start_no_incoming`. |
| 11.2 no outgoing exit edges | Same fixture requires `exit_no_outgoing`. |
| 11.2 reachability | Validation orphan test, parity case 6 and lifecycle severity/node-ID assertions. Uses normative §7.2 ERROR despite §11.12 saying warning. |
| 11.2 existing edge endpoints | Lifecycle fixture appends `ghost -> missing` to an AST and requires `edge_target_exists`; DOT creates implicit endpoint nodes. |
| 11.2 prompt warning | Lifecycle blank-prompt/label fixture exercises warning. Code follows normative §7.2 prompt **or label**, rather than checklist prompt-only wording. |
| 11.2 condition syntax | Invalid-condition lifecycle fixture requires `condition_syntax`. Full expression semantics remain a separate §11.9 audit. |
| 11.2 validate_or_raise | Lifecycle validation API test checks error exception with complete diagnostics and warning/info preservation on no-error return. |
| 11.2 diagnostic schema | Same test checks canonical rule/severity/message/target fields across all built-in rule families. Graph-wide errors need no node/edge target. |
| 11.10 graph stylesheet parsing | Parity case 18 and public malformed-stylesheet test exercise valid application and rejection diagnostics. |
| 11.10 shape selector | Parity case 18 and reasoning-effort stylesheet test check model/provider/effort. |
| 11.10 class selector | Specificity test and lifecycle preparation check class overrides. |
| 11.10 ID selector | Specificity test checks ID overriding class. |
| 11.10 four-level precedence | `all-selector-levels-compete-through-public-preparation` declares ID, class, shape and universal rules in decreasing priority order, then checks each winning model and an explicit override in one prepared graph. |
| 11.10 explicit attributes | Specificity and custom-property tests retain explicit model/property values. |

## Scoped edge defect

Subgraph `edge [...]` declarations updated the global defaults map. Closing the
subgraph restored node defaults but left edge weights and labels changed. The
new `edge-defaults-are-inherited-and-restored-at-subgraph-boundaries` test failed
before the fix. It checks inherited defaults, later declarations, explicit edge
overrides, nested restoration, top-level restoration and sibling isolation.

Edge defaults now live in each subgraph's scope record and inherit from the
parent when opened. Explicit edge attributes override that scope's defaults.

Verified after the fix: parser 11/46/0; validation 3/4/0; stylesheet 8/46/0;
lifecycle 8/162/0; parity 25/61/0; native build succeeds.

Evidence follow-up: the three gaps identified in this audit now have direct
assertions and pass without production changes. Updated focused results:
parser 12/49/0, validation 4/15/0, stylesheet 9/51/0. The initial cascade test
fixture used an unquoted hyphenated DOT value; it was corrected to a quoted
string before assessing precedence. Broader runtime execution, condition,
provider and release requirements remain outside this audit's scope.

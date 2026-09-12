# Condition audit — 2026-09-12

Scope: pinned Attractor §§10.2–10.5 and §11.9. This remains a partial audit.

| Checklist requirement | Evidence/finding |
|---|---|
| String equality | Existing outcome/context tests plus new exact-string regression. Fixed trimming of resolved values and quoted literal contents. |
| Inequality | Outcome inequality and new padded-string regression exercise inverse comparison. |
| AND clauses | Shared clause scanner splits only outside quoted strings and respects escapes. Evaluation uses `every?` for left-to-right short-circuiting after syntax parsing. Public pipeline regression routes on a quoted `&&` literal. |
| Outcome variable | Existing tests cover keyword success/fail and direct source inspection covers string-keyed outcomes. |
| Preferred label | Existing Yes-label test and new case-sensitive Go/go test. |
| Missing context values | Regressions check missing versus empty/space and qualified-nil fallback. Non-nil false/empty qualified values retain precedence. |
| Empty condition | Existing test accepts empty input independently of outcome. |

## Fixed exact comparison

`evaluate-clause` trimmed both resolved values and parsed literals. Thus a context
value `" ready "` matched the unquoted literal `ready`, and a missing key matched
`" "`. §10.3 requires exact case-sensitive comparison. Clause/literal syntax is
still trimmed, but data values and quoted contents now retain their whitespace.
Quoted literal contents also use the existing DOT string escape decoder, as
§10.5 requires, instead of retaining literal backslash sequences.

Five regression assertions failed before the fix. Conditions now pass 2/26/0;
parity 25/61/0 and engine 46/209/0 also pass. The regression covers padding,
inequality, newline/tab/quote/backslash escapes, missing/empty values, and case.

## Quoted syntax and fallback follow-up

The scanner now recognizes conjunctions outside strings, including escaped
quotes/backslashes. Validation and evaluation share clause parsing and literal
validation. Operator characters inside a quoted literal stay data; malformed
quoting, unsupported operators, invalid keys, and trailing literal text are
rejected. Thirteen assertions failed before these corrections and the nil
fallback change.

Qualified lookup now consults the unqualified spelling when its value is nil,
as §10.4 specifies. False and empty strings do not trigger fallback. Both string
and keyword-keyed maps are covered.

The public pipeline regression parses DOT, validates it, and executes conditional
branching: a value containing `&&` selects its matching branch and excludes the
higher-weight inequality branch. Conditions pass 6/52/0; parity 25/61/0,
lifecycle 8/162/0 and engine 46/209/0 also pass. Native build succeeds.

Compatibility: direct unqualified keys and bare-key truthiness remain supported
as in the existing implementation and §10.5 pseudocode, although the narrower
§10.2 grammar lists only comparisons. Empty clauses also retain the pseudocode's
skip behavior. These compatibility forms do not add new comparison operators.

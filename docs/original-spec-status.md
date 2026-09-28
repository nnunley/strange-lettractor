# Original-spec status — historical reconciliation and current pointers

OpenRouter Messages follow-up (2026-09-27): `anthropic/claude-haiku-4.5`
passes 7/7 strengthened same-session smoke steps in report `1790553400499`.
Parity covers 15/15 across that initial 14-row pass and steering rerun
`1790553802491`, after clarifying the first write call; assertions are unchanged.
This is gateway evidence. First-party Anthropic's quota-limited smoke remains
historical partial evidence. See [current provider results](provider-model-audits.md#live-coding-conformance-follow-up--2026-09-27).

OpenRouter follow-up: user-requested `or-responses/openai/gpt-5.2` checks use
the OpenAI Responses adapter/profile with gateway provenance. Combined parity
coverage is 15/15 across initial, targeted and final runs; the final strengthened
same-session smoke passes 7/7. Report `1790550366776` completes its selected
reasoning-change plus smoke scope (exit 0). This supplements accepted first-party OpenAI wire evidence without
claiming direct OpenAI live access. See the current provider evidence.

Live follow-up, 2026-09-27: same-session smoke is now implemented and native
conformance has partial live results. Anthropic covers 15/15 parity rows across
two runs; Gemini also has 15/15 across repaired full and targeted runs. Strengthened
Anthropic smoke passes five steps then hits quota-exceeded; Gemini strengthened smoke passes all seven steps. First-party OpenAI is wire verified, direct live not run,
and explicitly accepted by the user for publication without a push blocker. See [provider evidence](provider-model-audits.md#live-coding-conformance-follow-up--2026-09-27).
The current named audit includes this live-harness/profile work; the older
full-suite result below is dated repair evidence.

2026-09-27: the [coding-loop audit](coding-loop-audit-2026-09-27.md) records
four repaired implementation defects. The named audit passes 261 tests / 2529
assertions with zero failures/errors; earlier repair full suite passed 1566 tests / 14159 assertions with zero failures.
Custom environments require `:fork_scope` for independent child cancellation.
The coding parity runner now implements all fifteen rows; full native-provider
results and the seven-step shared-session smoke remain unproved. The older
eight/ten-row counts and credential statements below are dated history, not
the current state. See the audit and closure ledger for current obligations.

The remaining text reconciles 2026-09-11 records (runtime entry updated
2026-09-20), not a fresh completion audit.

For current repair status and remaining obligations, see the
[2026-09-23 specification closure](superpowers/iterations/spec-closure.md).
The historical evidence and gap statements below retain their original dates.

Generated reports are local/CI output under ignored `evidence/`, not repository
deliverables. See [verification output](verification.md). Coding-agent parity
is also partial: its scripted matrix covers eight of fifteen rows and its live
runner now covers ten. Historical gateway runs used generic profiles; the runner
now selects native tools by protocol. See `coding-agent-definition-of-done.md`.

Latest default-runtime suite: 1153 tests, 10330 assertions, zero failures,
including named schema anchors and embedded resource scope. This predates the
parity-runner-only changes. The fresh pinned-runtime result below is separate.

Update 2026-09-12: the execution audit found an original-scope cross-feature defect
despite completed story statuses: manager-started children bypassed transforms
and validation. It is now fixed with failing-before/passing-after and compiled
CLI evidence. See [runtime-execution-audit.md](runtime-audits.md).
The status ledger must not be used as proof that no implementation gaps remain.

Latest integrated verification: `make test` passes 1145 tests and 10284 assertions
with zero failures. This includes current Anthropic request compatibility and
omitted-model selection after middleware routing, and recursive-schema cycle
rejection and exact numeric multiples; see `default-model-audit.md` and
`structured-schema-audit.md`. This run uses a fresh clone of the documented
pinned runtime with both tracked patches; its build and native nREPL probes
also pass, as recorded in `runtime-build-audit.md`.
It does not close the live-provider, schema-conformance, or release-runtime gaps
below. Log: `/tmp/attractor-pinned-runtime-suite.log`.

The subsequent parsing, condition and human-interaction audits are recorded in
`runtime-parsing-validation-audit.md`, `runtime-condition-audit.md` and
`runtime-human-interaction-audit.md`. They corrected scoped edge defaults,
quoted condition parsing/comparison, queue exhaustion, and CLI timeout/EOF
answer semantics; each document distinguishes component evidence from broader
completion claims.

Fresh real-model runtime smoke evidence now passes against the configured local
llama.cpp provider, with stage artifacts and checkpoint retained under
`evidence/runtime-smoke-evidence/llamacpp-qwen3.8-27b-1789239367502/`. See
`runtime-integration-audit.md`. This closes the fresh runtime-smoke evidence gap,
not the unified-client provider matrix or release-runtime compatibility work.

A subsequent restart/HTTP audit found that hub checkpoint inspection kept reading
the first segment's directory after `loop_restart`. It now follows verified
restart publication for fresh and resumed workflows; the live checkpoint
regression and recovery results are in `runtime-execution-audit.md`.

The HTTP audit also found ignored question timeouts, collision-prone IDs and
incorrect JSON keys in the local runtime. These are fixed locally and verified
through native handler tests and a compiled-server loopback probe. See
[http-question-audit.md](http-question-audit.md); the runtime fix is preserved as
a tracked patch and is not yet evidence of upstream release compatibility.

The requirement ledgers cover 33 runtime stories, 13 coding-agent stories, and
12 unified-client stories. Their earlier complete statuses were not full-scope
proof: ULLM-RELEASE-01 is now partial, with missing or insufficient live matrix
evidence detailed in `unified-provider-evidence-audit.md`. Subsequent accumulator
and structured-stream repairs are recorded in `stream-accumulator-audit.md`.
ULLM-STRUCTURED-01 is also partial: `structured-schema-audit.md` records fixed
object-schema constraints and repaired containment/tuple-array gaps; dialect
selection and remaining schema keywords still need assessment.
Some rows include project extensions. Historical text and the roadmap
still contain pending reader, artifact and console-timeout notes superseded by
later completion entries; those are not reliable current gap lists.

Remaining original-scope closure work:

- Live Gemini parity is still recorded as credential-gated. OpenAI Responses and
  Anthropic Messages have live evidence through OpenRouter protocol-compatible
  endpoints, not direct first-party endpoint proof. See the requirement ledgers
  and `evidence/provider-matrix-evidence.edn`.
- Reconcile every original definition-of-done checkbox with current implementation
  and authoritative artifacts, then run the final integrated release verification.
  The earlier missing `parity-matrix-evidence.edn` citation finding is stale:
  `coding-agent-definition-of-done.md` now identifies the live runner, and evidence
  exists under `evidence/parity-matrix-evidence/` as per-model EDN files. These include
  OpenAI Responses and Anthropic Messages protocol runs, plus a Gemini model run
  through OpenRouter; that last file does not establish Gemini native-protocol
  parity. Existing artifacts still require requirement-by-requirement assessment.
- Closed 2026-09-20: the release-runtime gap. let-go 1.13.0 carries the native
  TCP listener and the JSON object-key fix, so the two tracked patches and the
  pinned fork revision are gone; `runtime-patches/` is deleted and `lgx.edn`
  pins 1.13.0. The full suite passes on the stock release with no `LGX_LG`:
  1336 tests, 10884 assertions, zero failures. Reader, cancellation and HTTP
  timeout behavior are exercised by that suite. Not covered by this run: the
  standalone listener probe and compiled nREPL attachment, which were last
  verified against the patched build.

Scope distinction: recursive context-budgeted development planning/execution,
automatic local-to-frontier escalation, paired development review, CSS custom
properties, and console job/context controls are user-requested extensions.
Their unfinished work must not be counted as unimplemented StrongDM requirements.

Sources: `specs/{attractor-spec,coding-agent-loop-spec,unified-llm-spec}.md`; `docs/superpowers/iterations/requirements/*.md`;
`docs/coding-agent-definition-of-done.md`; `evidence/provider-matrix-evidence.edn`.

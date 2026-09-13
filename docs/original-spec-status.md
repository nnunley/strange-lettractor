# Original-spec status — 2026-09-11

This is a reconciliation of existing records, not a fresh completion audit.

Update 2026-09-12: the execution audit found an original-scope cross-feature defect
despite completed story statuses: manager-started children bypassed transforms
and validation. It is now fixed with failing-before/passing-after and compiled
CLI evidence. See [runtime-execution-audit.md](runtime-execution-audit.md).
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
`docs/runtime-smoke-evidence/llamacpp-qwen3.8-27b-1789239367502/`. See
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
  and `provider-matrix-evidence.edn`.
- Reconcile every original definition-of-done checkbox with current implementation
  and authoritative artifacts, then run the final integrated release verification.
  The earlier missing `parity-matrix-evidence.edn` citation finding is stale:
  `coding-agent-definition-of-done.md` now identifies the live runner, and evidence
  exists under `docs/parity-matrix-evidence/` as per-model EDN files. These include
  OpenAI Responses and Anthropic Messages protocol runs, plus a Gemini model run
  through OpenRouter; that last file does not establish Gemini native-protocol
  parity. Existing artifacts still require requirement-by-requirement assessment.
- Runtime build reproducibility is now verified from a fresh clone of pinned
  fork revision `46244c4fa8169b8138aa1c29f31c8a6102ed1755` plus the two tracked
  patches. The full suite, build, listener probe, and compiled nREPL attachment
  pass. A stock upstream release containing the required changes remains
  unavailable; recheck reader, cancellation, and HTTP timeout behavior when
  moving to one. `let-go-followups.md` records the remaining upstream items and
  historical restoration notes; `runtime-build-audit.md` records the supported
  build that no longer depends on the old ignored source snapshot.

Scope distinction: recursive context-budgeted development planning/execution,
automatic local-to-frontier escalation, paired development review, CSS custom
properties, and console job/context controls are user-requested extensions.
Their unfinished work must not be counted as unimplemented StrongDM requirements.

Sources: `docs/upstream/strongdm-attractor/{attractor-spec,coding-agent-loop-spec,
unified-llm-spec}.md`; `docs/superpowers/iterations/requirements/*.md`;
`docs/coding-agent-definition-of-done.md`; `docs/provider-matrix-evidence.edn`.

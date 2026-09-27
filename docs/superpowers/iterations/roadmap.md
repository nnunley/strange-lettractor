# Iterative Delivery Roadmap

OpenRouter follow-up: user-requested `or-responses/openai/gpt-5.2` checks use
the OpenAI Responses adapter/profile with gateway provenance. Combined parity
coverage is 15/15 across initial, targeted and final runs; the final strengthened
same-session smoke passes 7/7. Report `1790550366776` completes its selected
reasoning-change plus smoke scope (exit 0). This supplements accepted first-party OpenAI wire evidence without
claiming direct OpenAI live access. See the current provider evidence.

2026-09-27 live follow-up: `lgx live-coding-conformance` now combines all
fifteen parity rows and the implemented seven-step same-session smoke, with
explicit provider/check/row scope and native-origin validation. Anthropic has
15/15 parity coverage across an initial 13-row pass and a targeted two-row rerun
after clarifying exact-output prompts (assertions unchanged). Gemini also covers
15/15 across its repaired full run and targeted loop-warning rerun. Strengthened
Anthropic smoke passes five steps before quota-exceeded in the subagent step;
timeout remains unrun. Gemini strengthened smoke passes all seven steps. Initial
weaker smoke evidence is excluded. First-party OpenAI is wire verified, direct live not run, and
explicitly accepted by the user for publication without a push blocker. See
[current provider
evidence](../../provider-model-audits.md#live-coding-conformance-follow-up--2026-09-27).
The current named audit includes these follow-ups. The earlier full-suite count
below remains dated repair evidence, not final publication verification.

Current original-spec closure is tracked in [spec-closure.md](spec-closure.md).

Closure follow-up, 2026-09-27: CAL-AUDIT-01 through CAL-AUDIT-04 from the
[coding-loop audit](../../coding-loop-audit-2026-09-27.md) are repaired with
regular regressions. `lgx audit-coding-loop` passes 261 tests / 2529 assertions,
zero failures/errors; earlier repair full suite passed 1566 tests / 14159 assertions with zero failures. Custom
environments need optional `:fork_scope` for independently owned child
cancellation. Patch targeting and the specification's event/state ambiguities
still need explicit disposition, alongside full live parity and shared-session
smoke evidence. This does not replace the user's existing catalog/integration
priority order.
User priority update, 2026-09-24: finish review/integration of ITER-0020, then
the provider-journey batch. Next implement the approved offline model-catalog
extraction before the shared-session integration smoke. Native-provider evidence
and the final original-spec audit follow; locally testable work continues while
provider access is unresolved. Gemini and Anthropic basic native access were
restored after user funding on 2026-09-24; their full journeys remain unproved.
Native OpenAI credentials are still unavailable. Keep Luna on the bounded
catalog task and Sol on provider integration.

The 2026-09-23 audit found additional schema, stream completion and custom
environment gaps despite historical completed story labels. ITER-0014 repairs
those gaps and records fresh evidence; the full original-spec audit remains open.

The repository already has a walking skeleton: DOT parse → transform/validate through supported entry points → deterministic handler execution → routing → EDN checkpoint/artifact persistence. `ITER-0000` records that imported baseline and the completed timeout hardening slice. Follow-on iterations close observable gaps in risk order.

| Iteration | Status | Scope | Stories | Scenarios |
|---|---|---|---|---|
| ITER-0021 Shared provider journeys | done:repair, 2026-09-24 (gpt-6-sol; full suite1526/13863/0, paired reviews/audits, compiled CLI gates) | Shared CLI/test journeys, generation/stream/parallel/extraction and404/429 contracts, preserved rows/routing, capability-aware cache/defaults and cleanup; Gemini original signatures and Anthropic signed-thinking history. Focused62/673/0; bounded native subsets pass on Gemini/Anthropic,429 remains unobserved. Batch2 in parity-evidence-plan.md | ULLM-CORE-01, ULLM-ADAPTER-01, ULLM-COMPLETE-01, ULLM-TOOLS-01, ULLM-ERROR-01, ULLM-QUIRKS-01, ULLM-RELEASE-01 | SCN-PROVIDER-JOURNEYS, SCN-GEMINI-SIGNATURES, SCN-PROVIDER-MATRIX |
| ITER-0020 Shared agent parity journeys | done:repair, 2026-09-24 (gpt-6-sol; final suite 1498/13585/0, paired reviews/audit, compiled CLI gates) | Factor reusable live/session journeys, add five missing parallel/steering/reasoning/subagent/loop-warning rows, and prove the same orchestration through all three native scripted protocols with real local tools and failure controls; preserve ten existing rows and CLI selection. Repair the discovered Gemini 2.5 budget serialization dependency. Batch 1 in parity-evidence-plan.md | CAL-PARITY-01, CAL-LOOP-01, CAL-REASON-01, CAL-STEER-01, CAL-SUBAGENT-01, ULLM-QUIRKS-01 | SCN-CAL-PARITY-JOURNEYS, SCN-CAL-PARITY-MATRIX, SCN-CAL-PARITY-LIVE |
| ITER-0019 Current model catalog | done:repair, 2026-09-23 (gpt-6-luna) | Sourced Opus/Sol/Luna metadata, preserved defaults/aliases, capability-driven Anthropic completion/stream behavior and prompt cutoffs; root focused 137/822/0, paired spec/quality approval, full suite 1485/13406/0 and fresh CLI validation; plan in catalog-refresh-plan.md | ULLM-CORE-01, ULLM-QUIRKS-01, CAL-SYSTEM-01 | SCN-CATALOG-REFRESH, SCN-ULLM-CLIENT, SCN-SYSTEM-PROMPT-BOUND |
| ITER-0018 Schema dialect and meta-validation | done:repair, 2026-09-23 (gpt-6-sol; fixture alignment gpt-6-luna) | Explicit 2020-12 and registered vocabulary semantics, resource-local dialects, schema preflight and all 1301 mandatory official cases; focused 20/88/0, fixture/LLM regression 108/616/0, paired spec/quality approval, full suite 1481/13376/0, six standalone probes and CLI validation; documented support contract in schema-dialect-plan.md | ULLM-STRUCTURED-01 | SCN-SCHEMA-DIALECTS, SCN-SCHEMA-REFERENCES |
| ITER-0017 Preparation contracts | done:repair, 2026-09-23 (gpt-6-luna) | Hyphenated DOT BareValue with strict keys/IDs, stylesheet reasoning enum, named custom lint objects and function/Var compatibility; root focused 40/327/0, paired spec/quality approval, full suite 1460/11894/0 and fresh CLI validation | ATTR-DOT-01, ATTR-VAL-01 | SCN-PREPARATION-CONTRACTS, SCN-ATTR-PARSE, SCN-STYLESHEET-SYNTAX, SCN-VALIDATION |
| ITER-0016 Runtime SKIPPED outcomes | done:repair, 2026-09-23 | Separate runtime/file status contracts; preserve routing, revisits, checkpoint transitions, branch and manager semantics. Focused 19/138/0, impacted 208/1506/0; paired reviews clean; integrated suite 1453/11844/0 and CLI validation pass | ATTR-ENG-01, ATTR-CP-01, ATTR-STATUS-01 | SCN-SKIPPED-OUTCOME |
| ITER-0015 Schema resource references | done:repair, 2026-09-23 (dialects/meta-validation remain partial) | RFC 3986 resolution, explicit registries, bundled resources, dynamic references/scopes and unresolved-reference failures; focused 61/716/0, including all 323 official reference/unevaluated cases; paired review clean; integrated suite 1453/11844/0 | ULLM-STRUCTURED-01 | SCN-SCHEMA-REFERENCES, SCN-SCHEMA-UNEVALUATED |
| ITER-0014 Original-spec closure repairs | done:repair 2026-09-23 (overall specification remains partial) | Unevaluated schema annotations, completed false/null stream values, standard execution-environment editing and raw/display separation, lgx 0.3.2 full suite 1417/11275/0 | ULLM-STRUCTURED-01, CAL-ENV-01, CAL-TOOLS-01 | SCN-SCHEMA-UNEVALUATED, SCN-CAL-ENV-EDIT, SCN-ULLM-HIGHLEVEL |
| ITER-0000 Walking skeleton and deadline safety | complete | Existing end-to-end mock journey plus cooperative deadlines, nested cancellation, process-group termination, and AOT | ATTR-DOT-01/02, ATTR-ENG-01/02, ATTR-CP-01, CAL-ENGINE-01 | SCN-ATTR-PARSE, SCN-ATTR-ENGINE, SCN-TIMEOUT, SCN-CHECKPOINT |
| ITER-0001 Status-file contract | done | Before each main/subgraph attempt: stale-file isolation; all specified JSON field types/outcome validation; unknown-field tolerance; file-over-handler precedence; handler fallback; exact auto synthesis; explicit-false inheritance; routing/event/checkpoint parity | ATTR-STATUS-01/02 | SCN-STATUS-FILE, SCN-AUTO-STATUS |
| ITER-0002 Public lifecycle preparation | done | Order-independent subgraph classes; one DOT-source public prepare/run lifecycle; built-in then custom transform order with input isolation; canonical diagnostics, custom rules, and validation gate shared by CLI/server | ATTR-DOT-03, ATTR-ENG-03, ATTR-VAL-01, ATTR-XFORM-01 | SCN-SUBGRAPH-LABEL, SCN-PUBLIC-LIFECYCLE, SCN-TRANSFORM-ORDER, SCN-VALIDATION, SCN-ATTR-ENGINE |
| ITER-0003 Run isolation and re-entry | done | Deep snapshot/branch clone semantics over the supported context value domain, plus stack-safe fresh-root loop restart with exact event, context, state, file-preservation, and global-step contracts | ATTR-CTX-01, ATTR-ENG-05 | SCN-CONTEXT-ISOLATION, SCN-LOOP-RESTART |
| ITER-0004 Pinned workflow recovery | done | Immutable prepared-workflow bundles, deterministic SHA-256 fingerprints, atomic publication, drift reporting, and pinned public resume | ATTR-CP-02 | SCN-PINNED-RECOVERY |
| ITER-0005 Context-mapped composition | done (temporary reader exception) | File-backed sub-pipeline API over captured plans with explicit ordinary-map input/output mappings, validation, failure propagation, and isolated child context/log/checkpoint state; full reader conformance remains ATTR-READ-01 | ATTR-COMPOSE-01 | SCN-PIPELINE-COMPOSITION |
| ITER-0006 Interactive concurrency | in progress | Handler/interviewer matrix, early `first_success`, prompted fan-in and supported-value artifact store/layout components verified; native console timeout, artifact reader exception and adopted discovery/recovery remain | ATTR-HND-01, ATTR-HUM-01/02, ATTR-ART-01/02, ATTR-PAR-02, ATTR-FANIN-01 | SCN-HANDLER-MATRIX, SCN-INTERVIEWERS, SCN-HUMAN-TIMEOUT, SCN-FIRST-SUCCESS, SCN-ARTIFACT-STORE, SCN-ARTIFACT-DISCOVERY, SCN-FANIN-RANKING |
| ITER-0007 Local tool-loop contracts | in progress | Local sequential/follow-up journey, scoped edit/write fixes, tool hooks and implemented-format read_file image/binary continuation verified; complete profile/tool/subagent contracts and remaining steering/reasoning parity still required | ATTR-HOOK-01, CAL-LOOP-01, CAL-REASON-01, CAL-PROFILE-01, CAL-TOOLS-01, CAL-STEER-01, CAL-SUBAGENT-01 | SCN-TOOL-HOOKS, SCN-CAL-LOOP, SCN-CAL-PROFILES, SCN-CAL-TOOLS, SCN-CAL-READ-FILE, SCN-CAL-SUBAGENTS |
| ITER-0008 Streaming observability | in progress (SSE, event families, session-error and turn-ownership components verified) | Maintained `/events` SSE and the complete §9.6 event families verified 2026-09-08; auth-no-retry and ordered terminal shutdown flush remain; typed errors/context-overflow recovery and current-turn-owned cancellation components verified | ATTR-SERVER-01, ATTR-OBS-01, CAL-ERROR-01, CAL-OWN-01 | SCN-SSE-LIVE, SCN-EVENT-FAMILIES, SCN-CAL-FAILURE-SHUTDOWN, SCN-CAL-TURN-OWNERSHIP |
| ITER-0009 Environment and prompt bounds | done:component 2026-09-10 | Raw/model truncation, provider-filtered 32 KiB project-instruction budget, runtime/git/model-metadata prompt snapshots and the FAIL retry-contract decision (2026-09-08) verified; exact execution-environment contract and sourced catalog cutoff coverage remain pending `SCN-CAL-ENV` complete: 15/117/0; sourced catalog cutoff coverage still pending. `SCN-CAL-ENV` and sourced catalog cutoffs closed. | CAL-ENV-01, CAL-TOOLS-01, CAL-TRUNC-01, CAL-SYSTEM-01, ATTR-ENG-04 | SCN-CAL-ENV, SCN-CAL-TRUNCATION, SCN-SYSTEM-PROMPT-BOUND, SCN-FAIL-RETRY-CONTRACT |
| ITER-0010 Transport contract harness | done:component 2026-09-08 | let-go loopback fixtures now hold headers, SSE bodies and JSON bodies and pace multi-chunk/tool streams; joined cancellation ownership verified. Remaining: adapter connect/request/read timeout distinctions, retry headers, malformed bodies, drops, server-observed disconnect `SCN-ULLM-HTTP-ERRORS` complete via `transport_matrix_server.lg` (6/76/0). | ULLM-CANCEL-01, ULLM-ERROR-01 | SCN-ULLM-CANCEL, SCN-ULLM-HTTP-ERRORS |
| ITER-0011 Client and adapter contracts | done:component 2026-09-08 | Client/default/middleware, low/high-level and structured APIs, native payload/response recording-server coverage, content, tools, reasoning, caching, quirks, catalog, and OpenAI-compatible endpoints `SCN-ULLM-CLIENT/HIGHLEVEL/TOOLS` (20/72/0) and `SCN-ULLM-ADAPTERS`/`SCN-OPENAI-COMPAT` (7/131/0) complete; provider id `openai-compat`. | ULLM-CORE-01, ULLM-MIDDLEWARE-01, ULLM-ADAPTER-01, ULLM-CONTENT-01, ULLM-COMPLETE-01, ULLM-STRUCTURED-01, ULLM-TOOLS-01, ULLM-QUIRKS-01, ULLM-COMPAT-01 | SCN-ULLM-CLIENT, SCN-ULLM-HIGHLEVEL, SCN-ULLM-TOOLS, SCN-ULLM-ADAPTERS, SCN-OPENAI-COMPAT |
| ITER-0012 Native loop and live release evidence | partial (credential-gated) | After transport/adapter contracts: native coding-loop continuation/profile/steering evidence, credential-gated provider matrix, and real Attractor smoke; skips are recorded but never treated as passes 2026-09-08: live matrix gate runs 8 journeys per configured provider; openai-compat 5 pass / 3 skipped; OpenAI/Anthropic/Gemini need credentials. 2026-09-10: CAL-LOOP/REASON/PROFILE/STEER/SUBAGENT/ERROR/TOOLS done at component level on the wire; live matrix passes on OpenRouter and Ollama Cloud; Anthropic ran with a real key but the account has no balance; OpenAI and Gemini have no keys. Only CAL-PARITY-01 and ULLM-RELEASE-01 remain, both blocked on funded native-provider keys. | ATTR-SMOKE-01, CAL-LOOP-01, CAL-PROFILE-01, CAL-STEER-01, CAL-SUBAGENT-01, CAL-PARITY-01, ULLM-RELEASE-01 | SCN-CAL-LOOP, SCN-CAL-PROFILES, SCN-CAL-SUBAGENTS, SCN-ATTR-SMOKE-LIVE, SCN-PROVIDER-MATRIX |
| ITER-0013 Remaining composition conformance | partial | Graph-merging transform validation/execution/capture and copied pinned recovery proved (3 tests / 63 assertions); restoration of the intended Clojure reader contract remains pending upstream compatibility fixes | ATTR-COMPOSE-02, ATTR-READ-01 | SCN-GRAPH-MERGE, SCN-CLOJURE-READER |

Every iteration closes with the impacted scenarios, the full sentinel suite, AOT compilation, parallel adversarial audit, and a public checkpoint commit. ITER-0013 records full-goal residuals identified by the ITER-0005 audit; it is not permission to treat the temporary reader subset as complete specification conformance. Its independent graph-merging proof has been brought forward and verified; the reader dependency must not prevent progress on unrelated pending iterations.

## User-requested console/RPC extension

Tracked independently in `docs/console-requirements.md`; does not replace any
StrongDM conformance iteration. Frontend framing (CONSOLE-INPUT-01) is implemented
with 7/92 focused and bundled evidence; paired audit clean. Full suite 686/6705/0.
The console must connect to a hub, not own the framework. Milestone reached on
2026-09-08 (`docs/superpowers/specs/2026-09-08-console-milestone-design.md`):
the in-process hub owns evaluation, workflows and external workers alongside
agent sessions; `attractor console` (line) and `attractor console --tui`
(tiny-tui) share one dispatcher; a live Qwen turn ran through it. Remaining:
separate-process RPC/nREPL transport with reconnect/replay, Codex app-server
worker, native resize/exception coverage, and a bounded live implementer
trial. See `docs/console-requirements.md` for evidence.

## Future work

User-requested extensions are collected in [`docs/future_work.md`](../../future_work.md).
User configuration beyond `.env` (settings file, precedence, trust) was
requested on 2026-09-08 and is recorded there as a bounded design item that
precedes packets. It is not part of any conformance iteration.

## Future design: executable packets and skill packages

Requested by the user on 2026-09-06. Record this as future design work, not an implemented capability or a replacement for the Attractor conformance iterations above.

The design session should settle:

- What an executable packet contains: workflow, executable code, skill instructions, assets, dependencies, and entry point; distinguish executable artifacts from serialized data.
- Skill package discovery, manifests, versions, dependency resolution, and compatibility requirements for let-go and lgx.
- How package identity and dependency fingerprints participate in pinned launch and recovery, including behavior when installed packages change or disappear.
- Trust and permissions: installation versus execution, explicit capabilities, secret handling, and validation before launching package code. Reading configuration must not implicitly execute it.
- Distribution choices: source bundles, compiled/AOT artifacts, or both; portability and reproducible builds. Keep `.edn` data files and the intended Clojure reader syntax contract.
- Evidence: install/load/run a packaged skill, launch an executable packet, and recover from the same pinned package versions after local changes.

These are design questions, not selected formats or APIs. Schedule a bounded design before implementation; do not add a package manager or expand the current reader workaround into one.

PEG improvements belong to a separate owner/workstream and must **not** be implemented by this agent. Any packaging dependency on PEG should be identified and handed off with an interface and acceptance criteria; neither PEG redesign nor a replacement Clojure parser is part of this agent's current work.

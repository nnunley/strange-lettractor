# Iterative Delivery Roadmap

The repository already has a walking skeleton: DOT parse → transform/validate through supported entry points → deterministic handler execution → routing → EDN checkpoint/artifact persistence. `ITER-0000` records that imported baseline and the completed timeout hardening slice. Follow-on iterations close observable gaps in risk order.

| Iteration | Status | Scope | Stories | Scenarios |
|---|---|---|---|---|
| ITER-0000 Walking skeleton and deadline safety | complete | Existing end-to-end mock journey plus cooperative deadlines, nested cancellation, process-group termination, and AOT | ATTR-DOT-01/02, ATTR-ENG-01/02, ATTR-CP-01, CAL-ENGINE-01 | SCN-ATTR-PARSE, SCN-ATTR-ENGINE, SCN-TIMEOUT, SCN-CHECKPOINT |
| ITER-0001 Status-file contract | done | Before each main/subgraph attempt: stale-file isolation; all specified JSON field types/outcome validation; unknown-field tolerance; file-over-handler precedence; handler fallback; exact auto synthesis; explicit-false inheritance; routing/event/checkpoint parity | ATTR-STATUS-01/02 | SCN-STATUS-FILE, SCN-AUTO-STATUS |
| ITER-0002 Public lifecycle preparation | done | Order-independent subgraph classes; one DOT-source public prepare/run lifecycle; built-in then custom transform order with input isolation; canonical diagnostics, custom rules, and validation gate shared by CLI/server | ATTR-DOT-03, ATTR-ENG-03, ATTR-VAL-01, ATTR-XFORM-01 | SCN-SUBGRAPH-LABEL, SCN-PUBLIC-LIFECYCLE, SCN-TRANSFORM-ORDER, SCN-VALIDATION, SCN-ATTR-ENGINE |
| ITER-0003 Run isolation and re-entry | done | Deep snapshot/branch clone semantics over the supported context value domain, plus stack-safe fresh-root loop restart with exact event, context, state, file-preservation, and global-step contracts | ATTR-CTX-01, ATTR-ENG-05 | SCN-CONTEXT-ISOLATION, SCN-LOOP-RESTART |
| ITER-0004 Pinned workflow recovery | done | Immutable prepared-workflow bundles, deterministic SHA-256 fingerprints, atomic publication, drift reporting, and pinned public resume | ATTR-CP-02 | SCN-PINNED-RECOVERY |
| ITER-0005 Context-mapped composition | done (temporary reader exception) | File-backed sub-pipeline API over captured plans with explicit ordinary-map input/output mappings, validation, failure propagation, and isolated child context/log/checkpoint state; full reader conformance remains ATTR-READ-01 | ATTR-COMPOSE-01 | SCN-PIPELINE-COMPOSITION |
| ITER-0006 Interactive concurrency | pending | Registry-to-engine handler matrix, interviewer matrix/timeout, true early `first_success` with loser join, artifact discoverability, prompted fan-in ranking | ATTR-HND-01, ATTR-HUM-01/02, ATTR-ART-01, ATTR-PAR-02, ATTR-FANIN-01 | SCN-HANDLER-MATRIX, SCN-INTERVIEWERS, SCN-HUMAN-TIMEOUT, SCN-FIRST-SUCCESS, SCN-ARTIFACT-DISCOVERY, SCN-FANIN-RANKING |
| ITER-0007 Local tool-loop contracts | in progress | Local sequential/follow-up journey and scoped edit/write fixes verified; tool hooks, complete profile/tool/subagent contracts, and remaining steering/reasoning parity still required | ATTR-HOOK-01, CAL-LOOP-01, CAL-REASON-01, CAL-PROFILE-01, CAL-TOOLS-01, CAL-STEER-01, CAL-SUBAGENT-01 | SCN-TOOL-HOOKS, SCN-CAL-LOOP, SCN-CAL-PROFILES, SCN-CAL-TOOLS, SCN-CAL-SUBAGENTS |
| ITER-0008 Streaming observability | pending | Maintained SSE, complete parallel/interview event families, auth-no-retry and ordered terminal shutdown flush | ATTR-SERVER-01, ATTR-OBS-01, CAL-ERROR-01 | SCN-SSE-LIVE, SCN-EVENT-FAMILIES, SCN-CAL-FAILURE-SHUTDOWN |
| ITER-0009 Environment and prompt bounds | partial | Per-family raw/model truncation separation verified through the shared output-handling path; exact environment contract, bounded project instructions, and FAIL retry-contract decision remain pending | CAL-ENV-01, CAL-TOOLS-01, CAL-TRUNC-01, CAL-SYSTEM-01, ATTR-ENG-04 | SCN-CAL-ENV, SCN-CAL-TRUNCATION, SCN-SYSTEM-PROMPT-BOUND, SCN-FAIL-RETRY-CONTRACT |
| ITER-0010 Transport contract harness | pending | Local controllable HTTP server for stalls, cancellation, retry headers, malformed bodies, drops, and stream accumulation | ULLM-CANCEL-01, ULLM-ERROR-01 | SCN-ULLM-CANCEL, SCN-ULLM-HTTP-ERRORS |
| ITER-0011 Client and adapter contracts | pending | Client/default/middleware, low/high-level and structured APIs, native payload/response recording-server coverage, content, tools, reasoning, caching, quirks, catalog, and OpenAI-compatible endpoints | ULLM-CORE-01, ULLM-MIDDLEWARE-01, ULLM-ADAPTER-01, ULLM-CONTENT-01, ULLM-COMPLETE-01, ULLM-STRUCTURED-01, ULLM-TOOLS-01, ULLM-QUIRKS-01, ULLM-COMPAT-01 | SCN-ULLM-CLIENT, SCN-ULLM-HIGHLEVEL, SCN-ULLM-TOOLS, SCN-ULLM-ADAPTERS, SCN-OPENAI-COMPAT |
| ITER-0012 Native loop and live release evidence | pending | After transport/adapter contracts: native coding-loop continuation/profile/steering evidence, credential-gated provider matrix, and real Attractor smoke; skips are recorded but never treated as passes | ATTR-SMOKE-01, CAL-LOOP-01, CAL-PROFILE-01, CAL-STEER-01, CAL-SUBAGENT-01, CAL-PARITY-01, ULLM-RELEASE-01 | SCN-CAL-LOOP, SCN-CAL-PROFILES, SCN-CAL-SUBAGENTS, SCN-ATTR-SMOKE-LIVE, SCN-PROVIDER-MATRIX |
| ITER-0013 Remaining composition conformance | partial | Graph-merging transform validation/execution/capture and copied pinned recovery proved (3 tests / 63 assertions); restoration of the intended Clojure reader contract remains pending upstream compatibility fixes | ATTR-COMPOSE-02, ATTR-READ-01 | SCN-GRAPH-MERGE, SCN-CLOJURE-READER |

Every iteration closes with the impacted scenarios, the full sentinel suite, AOT compilation, parallel adversarial audit, and a public checkpoint commit. ITER-0013 records full-goal residuals identified by the ITER-0005 audit; it is not permission to treat the temporary reader subset as complete specification conformance. Its independent graph-merging proof has been brought forward and verified; the reader dependency must not prevent progress on unrelated pending iterations.

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

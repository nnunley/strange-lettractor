# Specification Coverage Ledger

This ledger prevents a broad story title from hiding an uncovered Definition-of-Done surface. Detailed acceptance and evidence status live in `requirements/`; scenarios live in `behavior-scenarios.md`.

| Specification surface | Stories | Scenarios |
|---|---|---|
| Attractor DOT/schema/styles/conditions | ATTR-DOT-01/02/03, ATTR-STYLE-01, ATTR-COND-01 | SCN-ATTR-PARSE, SCN-SUBGRAPH-LABEL, SCN-ATTR-ENGINE |
| Attractor lifecycle/routing/retry | ATTR-ENG-01/02/03/04/05, ATTR-STATUS-01/02 | SCN-ATTR-ENGINE, SCN-TIMEOUT, SCN-STATUS-FILE, SCN-AUTO-STATUS, SCN-LOOP-RESTART, SCN-FAIL-RETRY-CONTRACT |
| Attractor handlers/human/parallel | ATTR-HND-01, ATTR-HUM-01/02, ATTR-PAR-01/02, ATTR-FANIN-01 | SCN-HANDLER-MATRIX, SCN-INTERVIEWERS, SCN-HUMAN-TIMEOUT, SCN-FIRST-SUCCESS, SCN-FANIN-RANKING |
| Attractor state/artifacts | ATTR-CP-01, ATTR-CTX-01/02, ATTR-ART-01 | SCN-CHECKPOINT, SCN-CONTEXT-ISOLATION, SCN-ARTIFACT-DISCOVERY |
| Attractor validation/transforms/composition/server/events/hooks | ATTR-VAL-01, ATTR-XFORM-01, ATTR-COMPOSE-01, ATTR-SERVER-01, ATTR-OBS-01, ATTR-HOOK-01 | SCN-VALIDATION, SCN-TRANSFORM-ORDER, SCN-PIPELINE-COMPOSITION, SCN-SSE-LIVE, SCN-EVENT-FAMILIES, SCN-TOOL-HOOKS |
| Attractor parity/smoke | ATTR-SMOKE-01 | SCN-ATTR-SMOKE-LIVE |
| Coding loop lifecycle/reasoning/steering | CAL-LOOP-01, CAL-REASON-01, CAL-STEER-01, CAL-ERROR-01 | SCN-CAL-LOOP, SCN-CAL-FAILURE-SHUTDOWN |
| Coding loop profiles/tools | CAL-PROFILE-01, CAL-TOOLS-01 | SCN-CAL-PROFILES, SCN-CAL-TOOLS, SCN-CAL-TRUNCATION |
| Coding loop environments/prompts | CAL-ENV-01, CAL-TRUNC-01, CAL-SYSTEM-01 | SCN-CAL-ENV, SCN-CAL-TRUNCATION, SCN-SYSTEM-PROMPT-BOUND |
| Coding loop subagents | CAL-SUBAGENT-01, CAL-ENGINE-01 | SCN-CAL-SUBAGENTS, SCN-TIMEOUT |
| Coding loop parity/smoke | CAL-PARITY-01 | SCN-PROVIDER-MATRIX |
| Unified client/config/middleware/catalog | ULLM-CORE-01, ULLM-MIDDLEWARE-01 | SCN-ULLM-CLIENT |
| Unified messages/content/results | ULLM-CONTENT-01 | SCN-ULLM-ADAPTERS |
| Unified low/high-level generation | ULLM-COMPLETE-01, ULLM-STRUCTURED-01 | SCN-ULLM-HIGHLEVEL, SCN-ULLM-CANCEL |
| Unified tool loop | ULLM-TOOLS-01 | SCN-ULLM-TOOLS |
| Unified errors/retries | ULLM-ERROR-01, ULLM-CANCEL-01 | SCN-ULLM-HTTP-ERRORS, SCN-ULLM-CANCEL |
| Unified native/compatible adapters and quirks | ULLM-ADAPTER-01, ULLM-QUIRKS-01, ULLM-COMPAT-01 | SCN-ULLM-ADAPTERS, SCN-OPENAI-COMPAT |
| Unified parity/smoke | ULLM-RELEASE-01 | SCN-PROVIDER-MATRIX |

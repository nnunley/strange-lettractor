# Iteration Log

## ITER-0000 — Walking skeleton and deadline safety

- Status: complete
- Delivered: deterministic mock pipeline journey; EDN checkpoint/artifact persistence; per-attempt timeout enforcement; cooperative cancellation through LLM requests, tool process groups, nested agents, manager and parallel branches; bounded polling; cancellation precedence; partial-output preservation.
- Evidence at revision `65f0403` on 2026-09-04: `LGX_LG=/Users/ndn/development/let-go/lg lgx test` reported 266 tests, 1,246 assertions, zero failures; `LGX_LG=/Users/ndn/development/let-go/lg lgx build` completed successfully. The specification-only revision `73e3a9d` did not change runtime behavior.
- Commits: timeout slice through `65f0403`; upstream specification snapshot `73e3a9d`.
- Sentinel scenarios: SCN-ATTR-PARSE, SCN-ATTR-ENGINE, SCN-TIMEOUT, SCN-CHECKPOINT.
- Project decision: internal serialization is EDN. JSON is retained only for provider/HTTP boundaries and explicitly external contracts such as `status.json`.

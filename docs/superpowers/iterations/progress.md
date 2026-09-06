# Progress

**Phase:** auditing ITER-0004
**Task:** pinned workflow recovery implemented; integration audit remains open
**Iterations:** 4 complete, 9 pending
**Sentinel corpus:** 4 established; last full run 401 tests / 2,483 assertions / 0 failures
**Current iteration:** ITER-0004 — pinned workflow recovery

**Audit follow-up:** `15604a2` makes checkpoint resume honor an outgoing restart edge through the ordinary restart driver. Canonical-path comparison, exact first event, unchanged departed checkpoint bytes, and fresh completed-node history now have regression assertions. Recovery: 48 tests / 433 assertions / 0 failures. Full suite and AOT pass. Paired audit retries have been dispatched.
**Last event:** 2026-09-06 — Direct integration audit repaired three publication gaps: fresh restart segments lacked local captures; direct `execute-prepared` calls skipped publication; and later restarts during resumed execution received a manifest instead of a runtime bundle. Verification now retains checked source bytes and decoded graphs in `:captured-bundle` for subsequent publication. Recovery evidence: 48 tests / 430 assertions; full suite: 401 / 2,480, all passing. Local let-go AOT build passed. Both paired audit workers stopped with usage-limit errors; their iteration audits remain unverified. ITER-0004 is not yet marked complete.

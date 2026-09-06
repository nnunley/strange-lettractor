# Progress

**Phase:** implementing ITER-0005
**Task:** implement authorized child-source resolution (Task 2)
**Iterations:** 5 complete, 8 pending
**Sentinel corpus:** 4 established; latest default suite at `6eda27f`: 412 tests / 2,694 assertions / 0 failures. Separate deferred reader check: 1 test / 5 failed assertions.
**Current iteration:** ITER-0005 — context-mapped composition

**Latest review:** The composition plan passed its chunk reviews. Task 1 configuration review found reader-syntax gaps. The user authorized a temporary ordinary-map path while native reader compatibility remains unresolved; do not count this as full Clojure-reader conformance. Pinned recovery was merged and pushed to public main at `f67cdc6` after both audits returned CLEAN; see [audit evidence](iter-0004-audit.md).

**Last event:** 2026-09-06 — Temporary mapping checkpoint `6eda27f` is pushed and passed scope and code-quality review with no blocking findings. Task 2 resolver implementation has started. Default mapping tests pass 7/163/0, public lifecycle passes 8/159/0, and the default suite passes 412/2694/0. The separate `compat/run_mapping.lg` command runs the five unresolved reader acceptance assertions and exits 1. Local-compiler AOT build succeeded; the compiled CLI accepts ordinary mapping configuration and rejects an engine-owned `run.id` destination with `subpipeline_config`. These checks do not yet prove child resolution or execution. [Reader issue #801](https://github.com/nooga/let-go/issues/801) remains open. No local let-go or PEG changes are part of this work. Executable-packet and skill-package design is deferred until a working Attractor is available.

**Nonblocking review follow-up:** Add exact diagnostic-key-set and multi-node lexical diagnostic-order assertions when extending composition evidence. Current implementation conforms; these are test-strengthening opportunities, not proved implementation defects.

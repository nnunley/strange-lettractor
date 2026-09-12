# Context, checkpoint and artifact audit

Audited 2026-09-12 against the pinned Attractor specification §§5.1, 5.3,
5.5–5.6 and §11.7. EDN persistence is the user's explicit format choice;
stage status files retain the external JSON contract.

| Contract | Inspected implementation and behavioral evidence |
| --- | --- |
| Context get/set, string conversion, update merge and append-only logs | context.lg uses one atom holding values/logs; updates preserve unrelated keys. Engine applies outcome updates before checkpoint creation. |
| Serializable deep snapshot and isolated branch clone | context_isolation_contract_test checks nested maps, vectors, lists and sets, separate clone/log identities and subsequent independent mutations; unsupported values fail with their path. |
| Checkpoint state fields and readback | context_test round-trips checkpoint data including optional fidelity and captured-workflow identity; engine writes completed node, retries, outcomes, context and logs. |
| Resume next node, preserve retries and degrade first full-fidelity hop | engine_test named resume cases and workflow_recovery_contract_test cover consumed retries, no repeat of completed failure, captured source recovery and first-hop fidelity. |
| Artifact storage, retrieval, metadata, removal and clearing | context_test covers UTF-8 threshold, inline/file-backed round-trip, missing values, rejected unsupported data and failed deletion retaining registrations. |
| Artifacts survive later handlers and resume | artifact_discovery_test uses fresh stores in later handlers and resumed runs and checks persisted outcome metadata. |

The audit exposed a collision introduced by persistent registration metadata:
both that metadata and a large artifact named `index` used
`artifacts/index.edn`. Three new assertions failed because retrieval returned
the registration map instead of the original payload. Metadata now lives in
`artifacts/.store/index.edn`, outside the artifact filename namespace. Existing
legacy indexes remain readable and are migrated before publishing a conflicting
payload. The regression verifies immediate retrieval, reopening, removal without
losing another artifact, and reading a legacy store before publishing `index`.

Fresh verification after the fix: context 12 tests/49 assertions; artifact
discovery 3/22; context isolation 2/91; workflow recovery 52/481. All pass, as
does the native CLI build and whitespace check. The previous integrated suite
result (1051 tests/9724 assertions) predates this artifact change.

Limits: these checks do not prove process-crash atomicity across payload and
metadata publication or concurrent mutation by independently opened stores.
The original §5.5 store lock protects one store instance; cross-process shared
store coordination is not established here. Existing payloads already destroyed
by the collision cannot be recovered from their metadata. This document is one
part of the completion audit, not a claim of whole-spec completion.

## Resume-log follow-up

The §11.12 parity test named checkpoint-resume originally only reloaded a
completed checkpoint. It now compares an uninterrupted run with a run stopped
after its first work stage and resumed from disk. This exposed dropped log
history: the resumed checkpoint contained only `consumed`, while uninterrupted
execution contained `prepared, consumed`. The engine now restores saved logs
before invoking resume observers or executing the next handler.

The test verifies that only unfinished work executes, prior context reaches the
next handler, and final traversal, retries, log history, semantic outcomes and
application context agree. Optional Outcome defaults added during loading are
compared semantically. Fresh parity checks pass 25 tests/75 assertions and
engine checks pass 46/209 after the fix.

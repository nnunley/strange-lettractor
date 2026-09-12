# Runtime integration audit

Audited 2026-09-12 against pinned Attractor §§11.11–11.13.

Transforms (§11.11): `lifecycle_contract_test` proves built-in expansion and
stylesheet transforms precede custom transforms, custom transforms run in order,
and validation sees the final graph before any handler starts. Fresh run: 8
tests/162 assertions, passing. The HTTP route names in §11.11 differ from the
specific §9.5 API; this implementation follows `/pipelines` and run-ID routes,
whose shared-hub evidence is documented in `shared-http-adapter.md`.

Cross-feature matrix (§11.12): the numbered tests in `parity_test.lg` map to all
22 matrix rows. Parsing/validation rows 1–6 check structure, attributes and
diagnostic severity; execution rows 7–16 exercise traversal, retries, gates,
selection priorities and context handoff. Row 17 now actually interrupts and
resumes, comparing against uninterrupted execution; it found and fixed lost
context logs. Rows 18–19 check resolved model and expanded prompt. The direct
fan-in test for row 20 is supplemented by the real parallel-pipeline case.
Rows 21–22 execute a custom handler and a twelve-node pipeline.

Two normative discrepancies remain explicit: reachability is an error under
§7.2 despite the matrix saying warning; returned FAIL routing follows §§3.5/3.7
as recorded in `fail_retry_contract_test.lg`, while retryable RETRY outcomes
exercise the configured retry count. Fresh parity result: 25 tests/75
assertions, passing. This does not elevate a single tested branch or outcome
to proof of all possible cross-feature combinations.

Smoke (§11.13): `smoke_test.lg` passes 1 test/24 assertions with deterministic
responses. `test/live/attractor_smoke.lg` uses the real agent backend for the
plan/implement/review pipeline and checks routing, nonempty responses, stage
status files, final checkpoint and events. It now retains run artifacts and
an EDN result under `docs/runtime-smoke-evidence/`, while deleting only the
model's temporary working directory.

Fresh local-model verification passes 1 test/20 assertions against the configured
`llamacpp/qwen3.8-27b` provider. Environment overrides were unset, but the native
provider registry supplied the endpoint; absence of overrides is not absence
of configuration. The initial sandbox DNS failure is recorded separately from
the successful network-enabled run. The successful evidence is
[result.edn](runtime-smoke-evidence/llamacpp-qwen3.8-27b-1789239367502/result.edn),
with complete stage artifacts and checkpoint in its sibling `logs/` directory.
The implementation response contains the hello-world source and review confirms
it. This establishes the runtime's real-LLM smoke journey; it does not establish
the other specifications' provider matrices or intended-runtime compatibility.

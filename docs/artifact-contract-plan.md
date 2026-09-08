# Artifact store and run metadata contract

Baseline: public `803ccb8`, production identical to verified `f9f7b30`.
Verified baseline 644/5970; candidate focused/bundled 3/64, impacted 138/920,
full default 647/6034, all zero failures. CLI build/help pass. Paired spec and
quality reviews approve; paired final component audit is clean. Set-valued data remains
limited by let-go #823, separate from this supported-store/layout component.
Scope derives from StrongDM Attractor §§5.5–5.6 and the user's internal EDN
serialization decision. Preserve external `status.json` and the separate pinned
`workflow/manifest.edn` format.

## Required changes and evidence

1. Write new run metadata (`id`, `goal`, `start_time`) to root `manifest.edn`
   using the existing non-evaluating EDN representation. Do not delete or rewrite
   legacy JSON manifests; there is no existing root-manifest reader to migrate.
   Test through actual public pipeline execution, not only the helper.
2. Complete the artifact store's §5.5 evidence: exactly 100KB stays in memory,
   one byte more is file-backed with a base directory, large data without a base
   directory stays in memory, metadata is complete, and typed retrieval agrees.
   Cover file-backed replacement by a small value and publication failure without
   corrupting prior registration/value. Existing EDN/Unicode/deletion tests remain.
3. In a public pipeline, a custom handler uses the real public store API under
   the supplied run root, returns artifact metadata in its outcome, and leaves
   file-backed EDN output retrievable. Independently inspect run metadata, stage
   `status.json`, checkpoint outcome metadata, and store contents. Verify separate
   fresh/restarted roots do not corrupt earlier artifacts.

## Scope boundary identified by source review

The earlier SCN-ARTIFACT-DISCOVERY promised final-result inventory and restoration
across resume, beyond the upstream store API. Do not silently discard that promise
or pretend these tests satisfy it. Keep discovery/reconstruction as a separately
pending adopted project requirement, with its existing scenario, and mark only
the source-grounded store/run-layout component complete when verified. No new
persistent index, automatic file scanning, or invented recovery protocol here.

## Verification

Permanent regression must fail for missing EDN manifest before the minimal code
change. Add a focused standalone runner; run impacted context/engine/recovery
contracts, full sentinel suite, bundle and CLI build/help. Paired scope/spec/
quality and final component audit gate publication. This does not complete all
artifact discovery, ITER-0006, or the full Attractor objective.

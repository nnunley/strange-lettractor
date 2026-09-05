# Pinned Workflow Recovery Design

**Date:** 2026-09-05
**Iteration:** ITER-0004
**Story:** ATTR-CP-02
**Scenario:** SCN-PINNED-RECOVERY

## Objective and Scope

A file-backed workflow must not silently change after launch. The public lifecycle captures one immutable prepared workflow, fingerprints it, and resumes that captured plan even when the original DOT file changes or disappears.

This iteration implements only the approved `:pinned` policy. Strict comparison/rejection and restart-on-current-source policies are deferred. It also does not promise exactly-once recovery inside a handler: resume starts after the last completed parent node, as Attractor §5.3 specifies. ITER-0005 subpipelines may rerun an interrupted child handler, but will use captured bytes rather than current files.

## Terms

- **Source identity:** the stable logical name of a DOT source inside a bundle.
- **Physical identity:** the symlink-resolved absolute path used for access control, deduplication, and cycle detection; it is not hashed into checkout-portable fingerprints.
- **Source digest:** SHA-256 of the exact UTF-8 source bytes.
- **Plan digest:** SHA-256 of the canonical EDN representation of a prepared graph.
- **Closure fingerprint:** SHA-256 of the versioned canonical bundle index.
- **Workflow bundle:** immutable sources, prepared plans, dependency records, and the closure fingerprint for one launched run.

## Source Resolution and Capture

`pipeline/prepare` retains its existing source-only arity and accepts optional `:source-path`, `:base-dir`, `:workflow-roots`, and injectable `:source-loader` values. The loader receives the containing source record and child reference and returns `{:logical-id string :physical-id string :source string}`.

The default loader resolves a child reference relative to its containing file, lexically cleans it, resolves symlinks, and requires the result to remain beneath one of the symlink-resolved workflow roots. Roots default to the root source directory or `:base-dir`. Absolute paths and `..` are accepted only when the resolved result remains in an allowed root. Non-`.dot` children are rejected. Authorization precedes reading.

The root logical identity is `workflow://root`. Child logical identities are normalized slash-separated paths relative to their matched workflow root. Physical identities deduplicate aliases and detect cycles; logical identities and references remain in the manifest, so changing a reference changes the closure fingerprint. An in-memory root without `:source-path` requires `:base-dir` for children.

DOT source is UTF-8 text. Hashing uses the exact string bytes supplied to the parser, including whitespace and line endings. Invalid filesystem UTF-8 is rejected before parsing.

## Recursive Preparation Contract

ITER-0004 establishes bundle machinery for the root graph; ITER-0005 activates recursive `subpipeline` references. The reusable preparation engine follows this contract:

1. Apply built-in transforms and caller transforms exactly once to a newly encountered physical source.
2. Validate the prepared graph with built-in and caller rules exactly once.
3. Discover transform-added child references from the prepared graph.
4. Visit references depth-first, sorting sibling nodes lexicographically by node ID.
5. Reuse a completed physical source; reject a physical source on the active stack as a cycle and include the logical reference chain.

Root diagnostics retain existing order. Composition diagnostics append in depth-first order. A child diagnostic is converted to canonical schema: `:node_id` names the referencing parent node, while `:message` includes child logical identity, chain, original rule, and original target. No noncanonical keys are added.

## Canonical Plan Encoding

Prepared graphs must round-trip through the project EDN domain. Unsupported values fail with category `:workflow_not_serializable` and an exact structural path; capture never hashes printed object addresses.

Version-1 canonical encoding is type-tagged and deterministic:

- nil, booleans, finite integers, finite decimals, strings, keywords, and symbols use a type tag plus EDN scalar representation;
- vectors and lists retain order and use distinct tags;
- map entries sort by canonical key bytes and then value bytes;
- set elements sort by canonical bytes;
- metadata is excluded;
- keys in namespace `attractor.runtime` are excluded; every other prepared-graph field is included.

NaN, infinities, opaque objects, mutable references, and duplicate canonical map keys are rejected. `canonical-edn` and `plan-fingerprint` are testable workflow utilities. Golden vectors lock scalar/container distinctions and the version-1 digest.

The version-1 closure index contains deterministic data only:

```edn
{:format-version 1
 :root-plan "<plan-sha256>"
 :sources [{:logical-id "workflow://root" :source-sha256 "<sha256>"}]
 :plans [{:logical-id "workflow://root"
          :plan-sha256 "<sha256>"
          :source-sha256 "<sha256>"
          :references []}]}
```

The closure fingerprint hashes the canonical index without a fingerprint field. Machine-specific physical paths appear only in diagnostic manifest records and are excluded from the fingerprint.

## Publication Protocol

`pipeline/prepare` reads but does not write. It returns `{:graph graph :diagnostics diagnostics :workflow bundle}`. Invalid preparation retains the no-run-directory/no-handler/no-event guarantee.

For valid `pipeline/run`, ordering is:

1. call existing `:on-prepared` before writes; if it throws, stop with no publication or engine activity;
2. create content directories;
3. publish sources and plans through sibling temporary files and rename;
4. verify and reuse an existing content-addressed target, or fail on mismatch;
5. publish `workflow/manifest.edn` last as the bundle commit marker;
6. call new `:on-published` with the prepared result and manifest path;
7. emit engine events and execute.

The server moves durable registration from `:on-prepared` to `:on-published`, so it cannot expose an unpublished run. `:on-prepared` remains a pre-publication gate. A pre-existing manifest must be byte-identical or publication fails with `:workflow_already_published`; it is never overwritten.

## Checkpoint and Public Resume

New EDN checkpoints preserve optional `:workflow_fingerprint`, `:workflow_manifest`, and `:current_fidelity`. Existing checkpoints remain readable.

`pipeline/resume checkpoint-path options` is the fingerprint-safe API. It loads the manifest relative to the checkpoint, matches checkpoint and manifest fingerprints, verifies every captured source and plan, decodes the root graph, optionally compares recorded physical source paths with current files, emits drift before pipeline start, and invokes low-level `engine/resume-pipeline` with the captured graph.

Current drift is a warning, not a blocker. The outcome `:diagnostics` gains one canonical `workflow_drift` warning listing logical identities and states in order. One `:workflow.drift_detected` event with the same ordered changes precedes `:pipeline.started`. No current source or transform is needed for recovery, and no current bytes replace captured bytes.

Missing capture fails with `{:category :workflow_snapshot_missing}`. Digest, format, plan, or checkpoint mismatch fails with `{:category :workflow_snapshot_corrupt}` and identifying fields. Both precede engine events and handlers.

Legacy callers retain low-level `engine/resume-pipeline checkpoint graph options`. CLI `resume` uses `pipeline/resume`; its DOT argument is only an optional current-source location for drift reporting and is never parsed for execution.

## Evidence

SCN-PINNED-RECOVERY proves SHA-256 golden vectors; checkout-independent fingerprints; source whitespace sensitivity; map/set construction-order independence; exact unsupported paths; allowed-root and symlink behavior; no writes on invalid preparation or failed pre-publication callback; content-first/manifest-last commit order; collision verification; server registration after commit; checkpoint fields and legacy reads; resume after current source change/removal/invalidity; drift warning/event order with captured behavior; corrupt/missing component failures before execution; and CLI resume routing.

Mutation-sensitive tests alter digests, canonical ordering, current files, and callback order. Focused tests, impacted lifecycle/checkpoint/server tests, the sentinel suite, and AOT close ITER-0004.

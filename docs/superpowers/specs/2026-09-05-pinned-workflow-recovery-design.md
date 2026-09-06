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

`pipeline/prepare` retains its existing source-only arity and accepts optional `:source-path`, `:base-dir`, `:workflow-roots`, and injectable `:source-loader` values. `:workflow-roots` is an ordered vector of `{:id string :path string}` records with unique IDs; it defaults to `[{:id "root" :path <root-source-directory-or-base-dir>}]`. Duplicate IDs with different paths are configuration errors. The loader receives the containing source record and child reference and returns `{:logical-id string :physical-id string :source string}`; logical IDs must be unique within the closure or preparation fails with `:workflow_identity_collision`.

The default loader resolves a child reference relative to its containing file, resolves path components and symlinks using filesystem semantics, and requires the result to remain beneath one of the symlink-resolved workflow roots. In particular, lexical cleanup must not collapse `link/..` before resolving the link. The longest resolved containing root wins; equal resolved paths choose the lexicographically smallest root ID. Absolute paths and `..` are accepted only when the resolved result remains in an allowed root. Both the reference and its resolved target must have a `.dot` extension. Authorization precedes content reading. This path-based check does not promise race-free confinement against a hostile actor concurrently replacing filesystem paths; descriptor-anchored secure opening would require separate work if roots are attacker-writable.

The root logical identity is `workflow://root`. A child logical identity is `workflow://<root-id>/<normalized-relative-path>` under its selected root. Physical identities deduplicate source preparation and detect cycles; multiple logical aliases of the same physical source are allowed. The first depth-first encounter is the primary plan, while every alias and reference remains in the index, so adding or changing an alias changes the closure fingerprint. An in-memory root without `:source-path` requires `:base-dir` for children.

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

Version-1 first converts every value to this exact canonical EDN tree, then hashes the UTF-8 bytes of let-go 1.12.2-or-newer `pr-str` over that tree:

```edn
["nil"]
["bool" true]
["int" "-12"]
["decimal" "1.50"]
["string" "text"]
["keyword" "optional.namespace-or-nil" "name"]
["symbol" "optional.namespace-or-nil" "name"]
["vector" [<encoded-values-in-order>]]
["list" [<encoded-values-in-order>]]
["map" [[<encoded-key> <encoded-value>] ...]]
["set" [<encoded-values> ...]]
```

Integer payloads are base-10 ASCII with one optional leading minus, no plus, and no leading zero except `"0"`. Decimal payloads are the exact scalar `pr-str`; positive and negative zero remain distinct when the runtime printer distinguishes them. Keyword and symbol namespace slots are EDN nil when absent, not the string `"nil"`. Map pairs sort lexicographically by encoded-key bytes and then encoded-value bytes. Set elements sort by encoded bytes. Vectors and lists retain order. Metadata is excluded. Every prepared-graph key and value is included; runtime data must not enter the prepared graph. Any change to this tree or scalar printer contract requires a workflow format-version bump.

An unsupported value fails as `{:category :workflow_not_serializable :path vector}`. The path starts `[:graph]`; vector/list values append their zero-based integer index, map values append their original serializable key, a bad map key appends the keyword `:map-key`, and a bad set element appends the keyword `:set-element`. For example, an opaque value under graph node `"work"` attribute `:handler` reports `[:graph :nodes "work" :attrs :handler]`.

NaN, infinities, opaque objects, mutable references, and duplicate canonical map keys are rejected. `canonical-edn` and `plan-fingerprint` are testable workflow utilities. Golden vectors lock scalar/container distinctions and the version-1 digest.

The runtime bundle has exact shape `{:format-version 1 :fingerprint string :root-plan-id "workflow://root" :plans map :index map}`. `:plans` maps every logical plan ID to `{:graph prepared-graph :plan-sha256 string :source-sha256 string :primary-plan-id string :references vector}`; aliases share their primary plan digest and graph. Each reference is exactly `{:node-id string :logical-reference string :plan-id string}`: `:logical-reference` is the exact `subpipeline.dotfile` attribute string, and `:plan-id` is its resolved logical child ID. References sort by node ID, then logical-reference, then plan ID; more than one record for the same node ID is invalid. Composition resolves a child by looking up the selected parent plan and then its reference with that node ID. `:index` is the deterministic persisted closure index below. It is derived by sorting the runtime plan map by logical plan ID and omitting graphs and physical paths:

```edn
{:format-version 1
 :root-plan-id "workflow://root"
 :sources [{:logical-id "workflow://root" :source-sha256 "<sha256>"}]
 :plans [{:logical-id "workflow://root"
          :primary-plan-id "workflow://root"
          :plan-sha256 "<sha256>"
          :source-sha256 "<sha256>"
          :references []}]}
```

The closure fingerprint hashes the canonical encoding of `:index`, which has no fingerprint field. The manifest stores the index, fingerprint, content locations, and diagnostic physical-path records. Machine-specific physical paths are excluded from the index and fingerprint.

## Publication Protocol

`pipeline/prepare` reads but does not write. It returns `{:graph graph :diagnostics diagnostics :workflow bundle}`. Invalid preparation retains the no-run-directory/no-handler/no-event guarantee.

For valid `pipeline/run`, ordering is:

1. call existing `:on-prepared` before writes; if it throws, stop with no publication or engine activity;
2. acquire `<logs-root>/workflow/.publish.lock` by exclusive directory creation; a valid existing manifest is verified and reused, while a lock without a manifest fails with `:workflow_publication_incomplete`;
3. create content directories;
4. publish sources and plans through UUID-named sibling temporary files and atomic rename;
5. verify and reuse an existing content-addressed target, or fail on mismatch;
6. publish `workflow/manifest.edn` last as the bundle commit marker, then release the lock;
7. call new `:on-published` with the prepared result and manifest path; and
8. emit engine events and execute.

The manifest is the only durable publication boundary. Content or temporary files without it are never resumed, and a stale lock without it is reported rather than guessed complete. Concurrent publishers serialize on the lock. A pre-existing manifest must be byte-identical or publication fails with `:workflow_already_published`; it is never overwritten. Orphan cleanup is future maintenance and cannot make an incomplete publication resumable.

The server moves durable registration from `:on-prepared` to `:on-published`, so it cannot expose an unpublished run. `:on-prepared` remains a pre-publication gate. `:on-published` must be idempotent: if it throws, the committed bundle remains valid, engine execution does not start, and a retry verifies/reuses the bundle before invoking the callback again. The server callback performs one nonthrowing atomic registry update.

## Checkpoint and Public Resume

New EDN checkpoints preserve optional `:workflow_fingerprint`, `:workflow_manifest`, and `:current_fidelity`. `:workflow_manifest` is exactly the relative path `"workflow/manifest.edn"`; resume derives the run root from the checkpoint parent and rejects absolute, escaping, or alternate manifest paths as `:workflow_snapshot_corrupt`. Existing checkpoints remain readable.

`pipeline/resume checkpoint-path options` is the fingerprint-safe API. It loads the manifest relative to the checkpoint, matches checkpoint and manifest fingerprints, verifies every captured source and plan, decodes the root graph, compares recorded physical source paths with current files when `:check-current?` is true (the default), emits drift before pipeline start, and invokes low-level `engine/resume-pipeline` with the captured graph. `:current-source-path` optionally overrides only the root source location used for comparison; child comparisons continue to use their recorded physical paths.

Current drift is a warning, not a blocker. Each drift record is `{:logical-id string :state keyword :expected-sha256 string}` with optional `:actual-sha256` and `:path`; states are `:changed`, `:missing`, `:unreadable`, or `:relocated`. Equal bytes at the same normalized, symlink-resolved physical path produce no drift. Equal bytes at a different normalized, symlink-resolved `:current-source-path` override are `:relocated`; unequal bytes there are `:changed`. Records sort by logical ID. When the vector is nonempty, the outcome `:diagnostics` gains exactly `{:rule "workflow_drift" :severity :warning :message (str "Pinned workflow differs from current sources: " (pr-str changes))}` and no noncanonical field. One `{:type :workflow.drift_detected :changes changes}` event with the same vector precedes `:pipeline.started`. With no drift, neither is emitted. No current source or transform is needed for recovery, and no current bytes replace captured bytes.

Missing capture fails with `{:category :workflow_snapshot_missing}`. Digest, format, plan, or checkpoint mismatch fails with `{:category :workflow_snapshot_corrupt}` and identifying fields. Both precede engine events and handlers.

Legacy callers retain low-level `engine/resume-pipeline checkpoint graph options`. CLI `resume` uses `pipeline/resume`; its DOT argument is only an optional current-source location for drift reporting and is never parsed for execution.

## Evidence

Integration clarification: `execute-prepared` is itself a public launch path and must publish or verify/reuse its bundle before execution. `run` still publishes before its `:on-published` callback; the execution handoff rechecks the capture. Every fresh loop-restart root receives the same bundle before restart/start events. Published verification retains checked source bytes and decoded plans as a runtime `:captured-bundle`, which resumed execution uses for later restart publication. Resume at a checkpoint immediately preceding a restart edge performs the same fresh-root transition as ordinary execution, preserving the departed checkpoint and resetting segment history.

SCN-PINNED-RECOVERY proves SHA-256 golden vectors including Unicode, numeric distinctions, and aliases; checkout-independent fingerprints; source whitespace sensitivity; map/set construction-order independence; exact unsupported paths; allowed-root and symlink behavior; no writes on invalid preparation or failed pre-publication callback; content-first/manifest-last commit order; concurrent publication and collision verification; callback failure/retry and server registration after commit; checkpoint fields, manifest-path confinement, and legacy reads; resume after current source change/removal/invalidity; exact drift warning/event order with captured behavior; corrupt/missing component failures before execution; and CLI resume routing.

Mutation-sensitive tests alter digests, canonical ordering, current files, and callback order. Focused tests, impacted lifecycle/checkpoint/server tests, the sentinel suite, and AOT close ITER-0004.

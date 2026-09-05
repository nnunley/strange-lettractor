# Context-Mapped Composition and Pinned Recovery Design

**Date:** 2026-09-05
**Iteration:** ITER-0004
**Stories:** ATTR-COMPOSE-01, ATTR-CP-02
**Scenario:** SCN-PIPELINE-COMPOSITION

## Objective

Implement StrongDM Attractor §9.4 sub-pipeline nodes as isolated child runs, with explicit context mappings and deterministic recovery when file-backed workflow definitions change. A launched run must execute one immutable prepared workflow closure. Resuming that run defaults to the captured closure rather than silently adopting current files.

Graph merging remains available through the existing custom-transform API. This iteration adds the runtime sub-pipeline pattern; it does not add a second graph-merging mechanism.

## Decisions

The approved public representation is a file-backed node:

```dot
compose [
  type="subpipeline",
  subpipeline.dotfile="flows/child.dot",
  input_map="{\"request.id\" \"request.id\", \"repo.path\" \"workspace\"}",
  output_map="{\"result\" \"child.result\"}"
]
```

`input_map` maps parent context keys to child context keys. `output_map` maps child context keys to parent context keys. Both values are quoted EDN maps whose keys and values must be strings. String-only mappings preserve the Context contract and avoid implicit keyword/name coercions.

Child paths resolve relative to the file that contains the referencing node. Direct callers that provide source text use `:source-path` or `:base-dir`; relative child references without either resolve from the process working directory for compatibility with existing file-oriented commands.

The default recovery policy is `:pinned`.

## Considered Approaches

### Recursive public lifecycle with isolated child execution — selected

The public pipeline layer recursively captures and prepares every referenced child before execution. Each child later executes from the captured prepared plan with a fresh Context, log root, checkpoint state, handler runtime, retry state, and fidelity state. This preserves the isolation and failure semantics required by ATTR-COMPOSE-01.

### Graph inlining transform — rejected

Inlining child nodes into the parent would reuse ordinary graph routing, but it would erase the required child Context, checkpoint, retry, log, and fidelity boundaries. It remains possible for callers to implement graph merging as an explicit custom transform, as allowed by upstream §9.4.

### Manager-loop adaptation — rejected

The manager handler already launches a child, but its observe/guard/steer/poll contract is supervisory. Reusing it for synchronous functional composition would expose unrelated telemetry keys and timing behavior while making transactional output mapping difficult.

## Workflow Bundle and Fingerprint

`attractor.pipeline/prepare` remains free of writes. After caller transforms run, it recursively loads all `subpipeline` references, parses their mappings, applies the same built-in/custom transform and validation lifecycle to each child, and returns an in-memory workflow bundle alongside the root graph and diagnostics.

The bundle contains:

- the prepared root graph;
- every prepared child graph, keyed by a stable logical source identity;
- the exact source bytes and SHA-256 for every root/child DOT source;
- normalized references and parsed mappings;
- a deterministic dependency order;
- a canonical prepared-plan digest for each graph; and
- one closure fingerprint.

The closure fingerprint is SHA-256 over canonical EDN containing logical source identities, exact source digests, dependency references, and canonical prepared-plan digests in deterministic order. It intentionally fingerprints the output of transforms rather than attempting to serialize transform functions. Canonical encoding sorts map entries and set elements by their canonical representation, so map iteration order cannot change the digest.

Cycles are rejected during recursive preparation with the complete reference chain. A source reached more than once is captured once, but each referencing node retains its own mappings.

After validation and the existing `:on-prepared` callback succeed, `pipeline/run` atomically publishes the bundle under the chosen run root before the first pipeline event or handler:

```text
<logs-root>/
  workflow/
    manifest.edn
    plans/<plan-fingerprint>.edn
    sources/<source-sha256>.dot
  checkpoint.edn
  ...
```

Temporary sibling files plus the existing move/publish pattern prevent partially written manifests or plans from looking valid. `manifest.edn` contains format version, closure fingerprint, root plan identity, source records, and plan records. Plans and sources are content-addressed and verified again when loaded.

Files may change after capture without affecting the launched run. Child execution never rereads the original path.

## Public Lifecycle

The public API gains composition-aware preparation and resume while preserving existing arities:

- `pipeline/prepare dot-source options` returns `:graph`, `:diagnostics`, and `:workflow`.
- `pipeline/run dot-source options` publishes the prepared workflow and invokes the low-level engine with it.
- `pipeline/resume checkpoint-path options` loads and verifies the captured workflow, then resumes its root prepared graph.

CLI `run`, `validate`, and `graph` pass the root source path so nested paths are stable. CLI `resume` delegates to `pipeline/resume`; the supplied DOT path is used for drift comparison or restart policy, never as an implicit replacement for the captured plan.

`engine/run-pipeline` and `engine/resume-pipeline` remain documented low-level prepared-graph seams. A low-level caller that bypasses `pipeline/run` must provide a workflow bundle to execute `subpipeline` nodes; otherwise the handler returns a configuration failure.

## Sub-Pipeline Execution

`subpipeline` becomes a standard handler type. The engine injects a run-scoped composition callback without mutating the caller's registry template.

For each parent attempt the handler:

1. Parses no files; it resolves the node's captured child plan from the workflow bundle.
2. Reads every mapped parent input. If any source key is absent, it returns FAIL before creating child state.
3. Builds a new child Context containing only deep-copied mapped inputs plus the child's own graph bookkeeping.
4. Creates an attempt-specific child log root and atomically records an invocation descriptor.
5. Runs or resumes the captured child plan with a cloned registry, fresh manager/parallel runtimes, child-local retries, child-local fidelity sessions, and inherited cancellation/event sinks.
6. On SUCCESS or PARTIAL_SUCCESS, collects all mapped outputs first. A missing output fails the composition without applying any output.
7. Returns mapped values as one `:context_updates` map, making the parent application transactional.
8. On FAIL or CANCELLED, returns the child's status and failure reason without parent output updates.

One sub-pipeline handler attempt consumes one parent step. Child steps use the child's own invocation-wide budget. Parent and child checkpoints, completed nodes, outcomes, retries, files, and fidelity sessions never merge.

Child lifecycle events are wrapped as `:subpipeline.child_event` with parent node ID, child log root, child fingerprint, and the original event. The handler's ordinary parent stage event still represents the composition boundary.

## Invocation Descriptors and Interrupted Children

Before a child starts, the parent writes an attempt descriptor under its stage directory. The descriptor contains a format version, parent node/attempt, child plan and closure fingerprints, child log root, mapping digests, and `:state :running`. Completion atomically replaces it with `:state :completed` and the final child outcome plus mapped output candidate.

On pinned parent resume, re-entry into the same logical sub-pipeline attempt behaves as follows:

- a verified completed descriptor reuses the recorded outcome and applies its recorded mapped output exactly once;
- a verified running descriptor with a child checkpoint resumes that checkpoint against the captured child plan;
- a verified running descriptor without a child checkpoint restarts the captured child at its existing isolated root;
- a corrupt, mismatched, or path-escaping descriptor fails explicitly and never launches current source bytes.

Parent retry advances the attempt number and creates a fresh child root and descriptor. It never reuses a failed attempt's child state.

## Recovery Policies

### `:pinned` — default

Load and verify the captured manifest, sources, plans, and checkpoint fingerprint. Resume from the captured prepared graph. If a current root source is supplied, prepare it only for comparison; a mismatch or unreadable current closure produces a `:workflow.drift_detected` diagnostic/event but does not prevent recovery. Pinned recovery never falls back to current files when captured material is absent or corrupt.

### `:strict`

Require a current source, prepare its closure, and compare the closure fingerprint. A mismatch throws before engine state or handler activity with category `:workflow_changed`, including expected and actual fingerprints plus changed logical sources when determinable.

### `:restart`

Prepare and run the current workflow under a new root. No completed nodes, retry counts, node outcomes, fidelity sessions, or arbitrary old context cross the boundary. Callers may provide an explicit `:recovery-input-map` from old checkpoint context keys to new root context keys; missing inputs fail before the new run starts. The old run and its captured bundle remain byte-stable.

## Validation and Failures

Composition diagnostics use the canonical validation schema and deterministic node/reference order. Preparation rejects:

- missing or blank `subpipeline.dotfile`;
- unreadable child files;
- malformed EDN mapping strings;
- non-map mappings;
- non-string mapping keys or values;
- two inputs targeting the same child key;
- two outputs targeting the same parent key;
- a child parse/validation error; and
- recursive source cycles.

Runtime missing inputs/outputs and captured-bundle corruption use explicit non-retryable configuration/recovery categories. Cancellation always outranks a concurrently completing child and joins child cleanup before returning. A child failure preserves its category, retryability, failure reason, and notes where present.

No validation or fingerprint error may reach a child handler. Invalid root preparation retains the existing guarantee of no run directory, checkpoint, pipeline event, or handler side effect.

## Compatibility and Serialization

Existing pipelines without `type="subpipeline"` retain their current graphs, outcomes, events, and public arities. Existing EDN checkpoints without fingerprint fields remain readable by `context/load-checkpoint`; legacy low-level resume continues to accept an explicitly supplied graph. Public pinned/strict recovery requires a versioned captured workflow and fails clearly when an old checkpoint has none.

Workflow manifests, prepared plans, invocation descriptors, checkpoints, and mapped internal values use EDN. JSON remains limited to provider/HTTP boundaries and `status.json`.

## Evidence Strategy

`SCN-PIPELINE-COMPOSITION` will prove, at the public lifecycle seam:

- relative nested file resolution and recursive transform/validation;
- exact input/output mapping and absence of unmapped/colliding values;
- transactional output application on SUCCESS/PARTIAL_SUCCESS only;
- FAIL/CANCELLED propagation and cleanup;
- distinct parent/child Context identities, roots, checkpoints, completed nodes, outcomes, retries, handler runtimes, and fidelity sessions;
- duplicate destinations, malformed mappings, missing files/keys, child validation errors, and cycles fail at the specified boundary;
- original files changed after preparation but before child launch cannot affect execution;
- deterministic SHA-256 manifests and content-addressed snapshot verification;
- pinned top-level resume after parent and child source drift;
- pinned recovery of running and completed child descriptors without relaunching current files or duplicating outputs;
- strict mismatch rejection before execution;
- restart under a new root with only explicit recovery inputs;
- corrupt/missing snapshot, plan, descriptor, and checkpoint-fingerprint failures; and
- CLI run/validate/resume routing through the public lifecycle.

Focused composition/fingerprint tests, impacted lifecycle/checkpoint/engine/manager/status tests, the full sentinel suite, and AOT compilation close the iteration. Mutation-sensitive checks will alter a captured digest, mapping destination, descriptor state, and post-capture source to demonstrate that each proof can fail for the intended reason.

# Context-Mapped Composition Design

**Date:** 2026-09-05
**Iteration:** ITER-0005
**Story:** ATTR-COMPOSE-01
**Scenario:** SCN-PIPELINE-COMPOSITION
**Depends on:** `2026-09-05-pinned-workflow-recovery-design.md`

## Objective and Scope

Implement StrongDM Attractor §9.4 sub-pipeline nodes as synchronous, isolated child runs. A parent explicitly maps inputs into a child and outputs back into the parent. Every child is prepared and captured before execution.

This iteration does not inline graphs, add manager supervision, or promise exactly-once recovery inside a handler. If interrupted while a subpipeline handler is active, parent resume re-enters it with a fresh child attempt/root using the captured plan. External effects retain the ordinary at-least-once handler contract.

## Node Contract

```dot
compose [
  type="subpipeline",
  subpipeline.dotfile="flows/child.dot",
  input_map="{\"request.id\" \"request.id\", \"repo.path\" \"workspace\"}",
  output_map="{\"result\" \"child.result\"}"
]
```

`input_map` maps parent string keys to child string keys. `output_map` maps child string keys to parent string keys. Blank/absent maps mean `{}`. Present values must be quoted EDN maps with string entries.

Lookup uses `contains?`, distinguishing present nil from missing. Two sources cannot target one destination. Output destinations may overwrite existing nonreserved parent values, but every output is collected before returning one transactional `:context_updates` map.

Engine-owned destinations are rejected: `run.id`, `current_node`, `outcome`, `preferred_label`, `graph.*`, and `internal.retry_count.*`. This applies to child destinations in `input_map` and parent destinations in `output_map`. Source sides may read any present key.

## Preparation and Validation

After transforms, the workflow preparer finds explicit `subpipeline` nodes in lexical node-ID order, parses mappings, resolves `subpipeline.dotfile`, and recursively prepares each new physical child once. Transform-added references are included. Completed sources are reused; active-stack references produce a cycle error with the logical chain.

Canonical error rules are `subpipeline_config` for dotfile/mapping/destination defects, `subpipeline_source` for unauthorized/non-DOT/unreadable/invalid-UTF-8 sources, and `subpipeline_cycle` for recursion. Child diagnostics are attributed to the parent reference boundary as defined by the pinned design. Any error prevents publication and every root/child handler.

## Lifecycle Interfaces

`pipeline/run` calls a public `pipeline/execute-prepared prepared options` seam after bundle publication. It accepts a validated prepared result with a verified bundle, installs a run-scoped composition callback, and invokes `engine/run-pipeline` for the selected plan.

Children call `execute-prepared` with their captured plan. They do not reprepare, rerun transforms/rules, reread files, or republish the root bundle. Thus root and children pass the same preparation/validation contract once and the same prepared-execution contract.

The engine receives `:workflow` and `:execute-subpipeline`. Low-level `engine/run-pipeline` remains valid for ordinary graphs. A subpipeline without those values returns non-retryable `:subpipeline_configuration_error`.

## Handler Data Flow

`subpipeline` is a standard handler installed in a cloned registry. Caller registry templates remain untouched. For each parent attempt it:

1. resolves the captured child by parent source identity and node ID;
2. requires every mapped parent input before creating child state;
3. deep-copies only mapped values into a new child Context;
4. creates a pairwise-unique root under `<parent-root>/<node-id>/children/`;
5. executes with cloned registry, fresh runtimes/retries/outcomes/fidelity/checkpoint, inherited cancellation/event sink, and child-local step budget;
6. on SUCCESS/PARTIAL_SUCCESS, collects all mapped outputs before returning them together;
7. on missing output, returns non-retryable `:subpipeline_mapping_error` with no updates; and
8. on FAIL/CANCELLED, preserves status/category/retryability/reason/notes with no outputs.

One subpipeline call consumes one parent step. Cancellation wins concurrent completion, propagates to and joins the child, closes child resources, and applies no output.

Child events retain order inside `{:type :subpipeline.child_event :parent_node_id ... :child_logs_root ... :child_plan_fingerprint ... :event ...}`. The parent stage event follows resolution.

## Recovery

Pinned resume uses captured children despite current file drift. An incomplete parent node reruns the child under a fresh root; old incomplete roots remain immutable evidence. A completed parent checkpoint skips the node and retains previously applied outputs. No current child bytes are used. Mid-child continuation and exactly-once external effects are out of scope.

## Evidence

SCN-PIPELINE-COMPOSITION proves EDN mapping syntax/defaults/types/nil/duplicate/reserved/overwrite behavior; relative and transform-added references; deterministic traversal/reuse/cycles; child validation attribution/no-handler gating; exact input/output isolation; transactional success/partial outputs; missing-output and FAIL/CANCELLED behavior; distinct parent/child state and budgets; cancellation order; drift-proof captured launches; incomplete-child rerun under a fresh root; completed-child skip; missing low-level runtime failures; and public lifecycle/CLI call counts.

Mutation-sensitive tests remove mapped keys, alias destinations, substitute current bytes, share runtimes, and reorder cancellation. Focused tests, impacted pinned/lifecycle/context/engine/manager/status suites, the sentinel suite, and AOT close ITER-0005.

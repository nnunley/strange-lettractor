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

`pipeline/run` calls public `(pipeline/execute-prepared prepared options)` after bundle publication. `prepared` must contain `{:graph map :diagnostics vector :workflow map}`. The workflow must contain `{:format-version 1 :fingerprint string :root-plan-id string :plans map}`. The seam rejects error diagnostics, unsupported formats, a selected graph unequal to its captured plan, or an in-memory closure fingerprint mismatch before installing handlers or emitting events. Root execution selects `:root-plan-id`; internal child calls select a plan with namespaced option `:attractor.pipeline/plan-id`. The namespaced wrapper option is removed before invoking `engine/run-pipeline`.

Children call `execute-prepared` with their captured plan. They do not reprepare, rerun transforms/rules, or reread current source files. Following the ITER-0004 recovery audit, each child publishes the full already-captured bundle under its own run root. This preserves closure identity and makes the child's checkpoint independently resumable without changing the original root bundle. Checkpoints carry optional `:workflow_plan_id` identifying the selected captured child; absent identity selects the original root for existing checkpoints. Unknown/non-string plan IDs fail before engine entry. Thus root and children pass the same preparation/validation contract once and the same prepared-execution contract.

The engine receives `:workflow` and `:execute-subpipeline`. The callback accepts `{:plan-id string :context Context :logs-root string :registry registry :cancelled? fn :on-event fn :max-steps positive-integer}` and returns the child Outcome from `execute-prepared` after verifying the selected captured plan. Low-level `engine/run-pipeline` remains valid for ordinary graphs. A subpipeline without those values returns non-retryable `:subpipeline_configuration_error`.

The handler is installed in a cloned registry. An explicit caller entry named `"subpipeline"` wins. Otherwise the engine replaces only its marked built-in placeholder with the run-scoped handler; the caller's registry template is never mutated.

Mapping configuration is derived by the same pure `node-config` function during capture and execution, from the verified captured node/graph attributes. No unpinned side cache is used. Both fresh and resumed execution supply the full verified runtime bundle, selected plan identity, and child execution callback, preserving them across restarts.

## Handler Data Flow

`subpipeline` is a standard handler installed in a cloned registry. Caller registry templates remain untouched. For each parent attempt it:

1. resolves the captured child by parent source identity and node ID;
2. requires every mapped parent input before creating child state;
3. deep-copies only mapped values into a new child Context; unsupported values fail as `:subpipeline_mapping_error` with `:cause-category :unsupported-context-value` and a structural path beginning `[:input_map <parent-key> <child-key>]` followed by the nested value path (for example, an opaque value at index 2 under parent `"payload"` mapped to child `"request"` reports `[:input_map "payload" "request" 2]`);
4. creates a pairwise-unique root under `<parent-root>/<safe-node-component>/children/`; IDs matching `[A-Za-z0-9_-]+` retain their spelling, others use `node-` plus SHA-256 of the original UTF-8 ID, with canonical parent containment checked before writes to reject symlink escapes;
5. executes with cloned registry, fresh runtimes/retries/outcomes/fidelity/checkpoint, inherited cancellation/event sink, and child-local step budget selected from node `subpipeline.max_steps`, graph `subpipeline.default_max_steps`, or `10000`, in that order and independently of the parent's remaining steps;
6. on SUCCESS/PARTIAL_SUCCESS, collects all mapped outputs before returning them together;
7. on missing output, returns non-retryable `:subpipeline_mapping_error` with no updates; and
8. on FAIL/CANCELLED, preserves status/category/retryability/reason/notes with no outputs.

One subpipeline call consumes one parent step. Cancellation wins concurrent completion, propagates to and joins the child, closes child resources, and applies no output.

Child events retain order inside `{:type :subpipeline.child_event :parent_node_id ... :child_logs_root ... :child_plan_fingerprint ... :event ...}`. The parent stage event follows resolution.

The event's `:child_plan_fingerprint` is the selected plan's `:plan-sha256`; the closure fingerprint remains the shared checkpoint workflow identity.

A missing mapped input or output has exact shape `{:status :fail :category :subpipeline_mapping_error :retryable false :failure_reason string :mapping {:direction :input|:output :source string :destination string}}`. Its reason is `Subpipeline node '<id>' is missing <parent|child> <input|output> '<source>' for '<destination>'`.

Preparation diagnostics use exact canonical message forms: `Subpipeline node '<id>' has invalid <attribute>: <reason>`, `Subpipeline node '<id>' cannot load '<logical-reference>': <reason>`, and `Subpipeline node '<id>' introduces source cycle: <chain>`.

## Recovery

Pinned resume uses captured children despite current file drift. An incomplete parent node reruns the child under a fresh root; old incomplete roots remain immutable evidence. A completed parent checkpoint skips the node and retains previously applied outputs. No current child bytes are used. Mid-child continuation and exactly-once external effects are out of scope.

## Evidence

SCN-PIPELINE-COMPOSITION proves EDN mapping syntax/defaults/types/nil/duplicate/reserved/overwrite behavior; canonical configuration/source/cycle messages; relative and transform-added references; deterministic traversal/reuse/cycles; child validation attribution/no-handler gating; exact prepared-plan verification and registry precedence; exact input/output isolation and deep-copy failure paths; transactional success/partial outputs; exact missing-input/output and FAIL/CANCELLED behavior; distinct parent/child state and budgets; cancellation order; drift-proof captured launches; incomplete-child rerun under a fresh root; completed-child skip; missing low-level runtime failures; and public lifecycle/CLI call counts.

Mutation-sensitive tests remove mapped keys, alias destinations, substitute current bytes, share runtimes, and reorder cancellation. Focused tests, impacted pinned/lifecycle/context/engine/manager/status suites, the sentinel suite, and AOT close ITER-0005.

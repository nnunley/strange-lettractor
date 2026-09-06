# Context-Mapped Composition Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture recursive DOT subpipelines before launch and execute them through the public lifecycle with explicit EDN mappings, isolated state, cancellation, and pinned recovery.

**Architecture:** Keep mapping/configuration logic in `attractor.composition`, recursive resolution/preparation in `attractor.capture`, and immutable serialization/publication in `attractor.workflow`. Pipeline owns launch/child callbacks; engine installs a scoped subpipeline handler in its cloned registry. Child checkpoints select a captured plan without changing closure identity.

**Tech Stack:** Local let-go 1.12.2+, lgx, EDN, SHA-256, clojure.test, native filesystem primitives, AOT.

**Design:** `docs/superpowers/specs/2026-09-05-context-mapped-composition-design.md` and pinned recovery design. ITER-0004 baseline is `f67cdc6`, 405 tests / 2,531 assertions. No live-provider credentials are required for these deterministic contracts.

All test commands below use `env LGX_LG=/Users/ndn/development/let-go/lg lgx test <one-file>`; lgx accepts only one test path. Run the full suite with the same prefix and no path. Use `apply_patch` for edits and preserve all existing worktrees.

Runtime findings: let-go `io/slurp` preserves raw string bytes and string `seq` converts through Go runes. The read-only probe `(= source (apply str (seq source)))` accepted UTF-8 `héllo 世界` and a genuine U+FFFD character, and rejected byte sequences `ff` and `c080` generated with `io/decode :hex`. Task 2 can use this strict UTF-8 check before parsing; extend tests with truncated multibyte sequences, surrogate encodings, and overlong encodings. `clojure.edn/read-string` reads only one form; Task 1 needs explicit whole-input consumption and cannot rely on that call alone.

## Chunk 1: Configuration and recursive capture

Configuration handoff: capture calls `composition/node-config` for diagnostics; the scoped runtime handler calls the same pure function on the verified captured node and graph attributes. Those original strings/numbers already participate in the plan fingerprint. Do not retain an unpinned side cache or add schema fields for parsed mappings.

Reader clarification (user, 2026-09-06): use Clojure reader syntax, the superset of EDN, rather than strict EDN or a hand-scanned string-map subset. Accept reader discards and metadata where valid, consume exactly one resulting value, and validate its map/string schema without evaluating forms. Keep `.edn` filenames. Check the local reader's capabilities and report any demonstrated Clojure compatibility bug to the user rather than silently narrowing the contract. The explicit `node-config` return envelope is `{:config validated-config :diagnostics []}` on success, or `{:config nil :diagnostics [canonical-errors...]}` on failure; the config fields listed below are nested under `:config`.

### Task 1: Mapping grammar and node configuration

Temporary user-approved exception: continue with ordinary string/string maps, whitespace, commas, comments, and string/Unicode escapes while [let-go #801](https://github.com/nooga/let-go/issues/801) is unresolved. The application currently rejects all metadata and discards, including leading/trailing discards supported by the runtime. Full reader support above remains **unmet**. Preserve runnable failing acceptance cases in `compat/`; see `docs/let-go-reader-compatibility.md` for the command and restoration criteria. Upstream fixes must be followed by replacing the scanner with safe whole-input native reading and restoring acceptance cases to default discovery.

Files: create `src/attractor/composition.lg` and `test/attractor/composition_contract_test.lg`; modify `src/attractor/validation.lg`.

- [ ] Write tests for `(composition/node-config node graph)` returning `{:input-map map :output-map map :max-steps positive-integer :dotfile string}` or canonical configuration diagnostics. Blank/absent mapping strings mean `{}`; other forms must contain exactly one EDN map of string/string entries. Reject trailing forms, duplicate destinations, engine-owned destination names/prefixes, malformed EDN, missing/blank dotfile, and invalid budgets. Source names may be reserved. Nil input values are tested later at runtime, not forbidden by configuration.
- [ ] Run the focused file and observe undefined-module/function failure.
- [ ] Implement pure parsing/validation with deterministic attribute order: dotfile, input_map, output_map, budget. Budget precedence: node `subpipeline.max_steps`, graph `subpipeline.default_max_steps`, 10000. Return canonical `subpipeline_config` error maps with `:node_id`, exact design message prefix, and no extension keys. Add `subpipeline` to standard types and register its config rule without changing order of pre-existing rules. Keep parsed config outside the prepared graph so capture fingerprints remain reproducible.
- [ ] Run composition and lifecycle files separately; verify valid unrelated graphs retain diagnostics and transform call counts.
- [ ] Commit `feat(composition): validate explicit EDN context mappings`.

### Task 2: Authorized source resolver

Files: create `src/attractor/capture.lg` and `test/attractor/capture_contract_test.lg`; use `src/attractor/workflow.lg` root configuration helpers through a small documented utility surface if needed.

- [x] Add filesystem tests for relative children, in-memory roots with base-dir, absolute/parent references inside roots, outside-root refusal, symlink escapes, nested/overlapping roots, equal-root lexicographic tie-breaking, non-DOT extensions, unreadable files, and invalid UTF-8. Assert authorization happens before file read with a read spy.
- [x] Run capture test and verify failure before implementation.
- [x] Implement `(capture/resolve-source containing reference options)` returning `{:logical-id string :physical-id string :source string}`. Resolve physical paths before authorization, choose longest containing canonical root then smallest root ID, assign `workflow://<root-id>/<relative-path>`, and require `.dot`. Injected source-loader receives containing source record and literal reference; validate its output. Inspect local let-go filesystem/string APIs for strict UTF-8 validation; do not silently replace invalid bytes. Errors become canonical `subpipeline_source` diagnostics at the parent node boundary.
- [x] Run focused tests, including loader call counts, before committing `feat(capture): resolve authorized workflow sources`.

Task 2 evidence: `2c06f76`, scope and quality reviews approved. Capture 11 tests / 45 assertions; impacted recovery 52/481 and lifecycle 8/159; root's independent default suite 423/2739, all zero failures. Initial stub produced 39 failed assertions; the disguised-target-extension regression produced two failures before its fix. Filesystem confinement is a pre-read canonical-path check, not descriptor-anchored protection against hostile concurrent filesystem mutation. Parent-node diagnostic wrapping is part of Task 3. Run lgx tests sequentially: concurrent invocations in one worktree can overwrite their shared generated runner.

### Task 3: Recursive prepare and closure bundle

Files: modify `src/attractor/capture.lg`, `src/attractor/pipeline.lg`, `src/attractor/workflow.lg`; extend capture/composition/recovery tests.

- [ ] Write public prepare tests proving parent then lexical-node depth-first traversal, transform-added references, exactly one parse/transform/validation per physical source, physical alias reuse, active-stack cycle rejection with logical chain, duplicate logical-ID collisions, child diagnostic attribution and ordering, and no writes/events/handlers for errors anywhere in closure.
- [ ] Run these files separately and observe missing-child-capture failures.
- [ ] Implement recursive prepare using a supplied single-source prepare function, avoiding capture↔pipeline namespace cycles. Track active physical stack, completed physical plans, logical aliases, and ordered diagnostics. Build references exactly `{:node-id :logical-reference :plan-id}`, sorted by node ID/reference/plan ID; first depth-first physical encounter is primary. Root remains `workflow://root`. Build sorted source/plan index via a reusable workflow bundle constructor; hash all aliases/references and exclude physical paths. Validate every reference target, primary alias relation, source/plan binding, and duplicate reference node before publication and on resume.
- [ ] Run capture, composition, recovery, lifecycle, parser, and validation files. Assert unchanged root-only fingerprints/golden vectors and existing source-only prepare arity.
- [ ] Commit `feat(capture): snapshot recursive prepared workflow closures`.

## Chunk 2: Isolated child execution and recovery

Required runtime handoff: both fresh `execute-prepared` and public resume inject the verified full runtime bundle as `:workflow`, selected plan identity, and `:execute-subpipeline` callback into engine options. Resume obtains these from `:captured-bundle`, never the manifest alone or current files. The callback closes over that captured bundle and invokes the same selected-plan public execution seam for every descendant. Internal child options cannot replace the capture, selected graph, or callback. Restart plumbing preserves this handoff.

Child path contract: use an unchanged node ID only when it matches `[A-Za-z0-9_-]+`; otherwise use `node-` plus SHA-256 of the UTF-8 node ID as its directory component. Put child roots below `<parent-root>/<safe-component>/children/<uuid>`. Verify canonical containment beneath the parent root before creating child files, rejecting pre-existing symlink escapes. Add slash, parent traversal, absolute-looking, Unicode, separator, and symlink cases. Original node IDs remain unchanged in graphs, mappings, and event fields.

Event identity: `:child_plan_fingerprint` is the selected child plan's `:plan-sha256`, not the closure fingerprint. Assert it against the captured index while separately proving parent and child checkpoints share closure identity.

Isolation evidence matrix: parent, child, grandchild, and sibling runs must have distinct checkpoint files, completed-node vectors, outcome maps, retry maps, parallel/manager runtime slots, budget counters, and fidelity histories. Mutate or consume each kind in one run and assert the others are unchanged. Cover nested context values and caller registry/runtime templates as well as file paths; successful outcomes alone are insufficient.

### Task 4: Selectable captured-plan checkpoints

Files: modify `src/attractor/workflow.lg`, `src/attractor/pipeline.lg`, `src/attractor/context.lg`, `src/attractor/engine.lg`; extend recovery/context/composition tests.

- [ ] Write tests selecting a captured child via internal `:attractor.pipeline/plan-id`. Assert selected graph equals its stored plan, closure fingerprint stays unchanged, each child root has a verified local capture, and checkpoint `:workflow_plan_id` selects the child on resume. Missing optional field means original root for old checkpoints; unknown/non-string selection fails before engine entry.
- [ ] Run focused tests and verify failure.
- [ ] Generalize prepared verification to verify the whole closure against its original root, then compare the selected graph separately. Publish/reuse the full capture under each child root. Thread optional plan identity through stage/final checkpoints and restart options. Public resume selects that verified graph and validates checkpoint history against it, never a caller graph. Strip wrapper selection before engine call and inject a validated engine plan-ID option. Preserve root-only compatibility and previous restart capture guarantees.
- [ ] Run recovery, context, engine, lifecycle, and loop-restart files separately.
- [ ] Commit `feat(recovery): retain selected captured child plans`.

### Task 5: Mapping execution and scoped handler

Files: extend `src/attractor/composition.lg`; modify `src/attractor/handlers.lg`, `src/attractor/engine.lg`, `src/attractor/pipeline.lg`; extend composition tests.

- [ ] Write a public parent/child journey with present-nil and nested mapped inputs, an unmapped secret, child output overwrite, and a second missing output. Prove deep isolation and all-or-nothing outputs; missing inputs create no child root. Exercise success/partial success/failure/cancellation exact outcome propagation, exact missing mapping error shape/message, and opaque nested input path remapping.
- [ ] Run focused test and observe absent handler behavior.
- [ ] Implement a marked default placeholder in the registry, replaced only in the engine's cloned registry by a run-scoped handler. Explicit custom `subpipeline` entries win. Resolve the child through selected parent-plan reference/node ID. Deep-copy only mapped inputs into new Context; create UUID child roots beneath parent node `children/`; call injected execute-subpipeline callback with selected plan/context/root/registry/cancellation/events/budget. Gather every output before returning one context_updates map. Preserve failure/cancel category/retryability/reason/notes without outputs. Low-level calls without workflow/callback return nonretryable subpipeline_configuration_error.
- [ ] Run composition, handlers, lifecycle, context isolation, status, and engine files separately; verify parent registry template stays unchanged and sibling child runtime atoms differ.
- [ ] Commit `feat(composition): execute isolated mapped child workflows`.

### Task 6: Cancellation, budgets, events, and pinned reruns

Files: extend composition/capture/recovery tests; adjust runtime modules only for proved gaps.

- [ ] Add public parent-child-grandchild scenarios for independently selected child budgets, one parent step per call, fresh fidelity histories, cancellation during active child work, child join/cleanup before parent terminal events, and no late outputs. Assert exact ordered `subpipeline.child_event` envelopes with parent node, child root, child plan fingerprint, and nested event.
- [ ] Add file-drift/deletion tests after prepare and before execution/resume. Prove incomplete parent child-node retries under a fresh child root from captured bytes; completed parent node is skipped with outputs retained. Assert old child files/checkpoints remain unchanged, each child checkpoint resumes its selected graph, and restart roots remain captured.
- [ ] Run focused tests, implement only identified gaps, rerun to green.
- [ ] Run impacted recovery, lifecycle, CLI, server, manager/handlers, engine, context and status files separately; commit `test(composition): prove cancellation and pinned child recovery`.

## Chunk 3: Audit and integration

### Task 7: Durable scenario evidence and public checkpoint

Files: `docs/superpowers/iterations/{behavior-scenarios,behavior-corpus,progress,roadmap}.md`, `docs/superpowers/iterations/requirements/attractor.md`, `README.md`, composition tests.

- [ ] Run the complete suite and AOT with the local compiler; compare baseline 405/2531/0. Preserve failures as evidence and fix them before completion claims.
- [ ] Run paired three-tier adversarial audits: deep ATTR-COMPOSE-01/SCN-PIPELINE-COMPOSITION; impacted pinned recovery/lifecycle/context/engine/status/manager/CLI/server; established parser/engine/timeout/checkpoint sentinels. Require explicit inspection of authorization-before-read, alias identity, exact child selection, transactional output, cancellation join, and interrupted-child recovery. Remediate and re-review every finding.
- [ ] Add `;; SCN-PIPELINE-COMPOSITION COMPLETE` only after scenario proof, update corpus and requirements to done:ITER-0005, and document child-run semantics in README/tutorial without claiming whole-spec completion.
- [ ] Commit, fast-forward main while preserving unrelated changes/worktrees, run full suite/AOT on main, push public main and verify remote commit. Next roadmap work remains ITER-0006.

# Pinned Workflow Recovery Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture every launched root workflow as a deterministic, immutable EDN bundle and resume the captured graph safely even when its source file changes or disappears.

**Architecture:** Add a focused `attractor.workflow` module for canonical encoding, SHA-256 identity, publication, verification, and drift comparison. Keep `attractor.pipeline` responsible for the public prepare/run/resume lifecycle, thread only workflow identity through checkpoints in `context`/`engine`, then move CLI and server onto that lifecycle. ITER-0004 captures the root plan only; the runtime bundle and reference schema deliberately leave the recursive slot that ITER-0005 composition will populate.

**Tech Stack:** let-go 1.12.2+, EDN, native `hash/sha256`, `os/canonical-path`, `os/rename`, `clojure.test`, lgx, AOT.

**Design:** `docs/superpowers/specs/2026-09-05-pinned-workflow-recovery-design.md`

---

## File Structure

- Create `src/attractor/workflow.lg`: canonical value tree, fingerprints, root bundle construction, publication/verification, and drift comparison. No engine or CLI behavior belongs here.
- Create `test/attractor/workflow_recovery_contract_test.lg`: the complete `SCN-PINNED-RECOVERY` contract and exact completion marker.
- Modify `src/attractor/pipeline.lg`: public prepare/run/execute-prepared/resume lifecycle and callback ordering.
- Modify `src/attractor/context.lg`: lossless optional workflow checkpoint fields.
- Modify `src/attractor/engine.lg`: include workflow identity in every checkpoint and accept pre-start events without changing the low-level graph API.
- Modify `src/attractor/cli.lg`: route resume through the captured workflow and treat the DOT path as optional drift input.
- Modify `src/attractor/server.lg`: register a run only after bundle publication.
- Modify focused existing tests only where their public expectations change: `test/attractor/context_test.lg`, `test/attractor/engine_test.lg`, `test/attractor/lifecycle_contract_test.lg`, `test/attractor/cli_test.lg`, and `test/attractor/server_test.lg`.
- Modify iteration evidence only after all proof passes: `docs/superpowers/iterations/behavior-corpus.md`, `progress.md`, `roadmap.md`, and `requirements/attractor.md`.

## Chunk 1: Deterministic Capture and Publication

### Task 1: Canonical EDN and SHA-256 identities

**Files:**
- Create: `src/attractor/workflow.lg`
- Create: `test/attractor/workflow_recovery_contract_test.lg`

- [ ] **Step 1: Write failing canonical-tree and digest tests**

Add namespace imports for `hash`, `clojure.edn`, `clojure.string`, `io`, and `os`. Test exact trees for nil, booleans, integer/decimal/string/keyword/symbol, vector/list/map/set; Unicode; negative zero when distinguishable; map/set construction-order independence; and the exact unsupported paths `[:graph :nodes "work" :attrs :handler]`, `[:graph :map-key]`, and `[:graph :set-element]`. Lock at least three literal SHA-256 golden strings computed independently with `shasum -a 256` or `openssl dgst -sha256`.

The public utility surface must be:

```clojure
(workflow/canonical-tree value)
(workflow/canonical-edn value)
(workflow/sha256-text text)
(workflow/plan-fingerprint graph)
(workflow/closure-fingerprint index)
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/workflow_recovery_contract_test.lg`

Expected: FAIL because `attractor.workflow` does not exist.

- [ ] **Step 3: Implement the canonical encoder exactly from the design**

Use a recursive helper carrying a path. Encode only to vectors containing strings, booleans, nil, and recursively encoded vectors; serialize the final tree once with `pr-str`. Sort map pair trees and set element trees by their serialized bytes. Before returning any scalar tree, confirm its `pr-str` round-trips through EDN. Reject non-finite or unsupported values with:

```clojure
(throw (ex-info "Workflow value is not serializable"
                {:category :workflow_not_serializable
                 :path path}))
```

Hash only strings via `(hash/sha256 text)`. Do not filter graph keys or stringify opaque values.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the focused command from Step 2.

Expected: all canonicalization tests pass; the scenario COMPLETE marker is not added yet.

- [ ] **Step 5: Commit**

```bash
git add src/attractor/workflow.lg test/attractor/workflow_recovery_contract_test.lg
git commit -m "feat(workflow): add deterministic plan fingerprints"
```

### Task 2: Build the immutable root runtime bundle

**Files:**
- Modify: `src/attractor/workflow.lg`
- Modify: `src/attractor/pipeline.lg`
- Test: `test/attractor/workflow_recovery_contract_test.lg`
- Test: `test/attractor/lifecycle_contract_test.lg`

- [ ] **Step 1: Write failing root-capture tests**

Prove that `pipeline/prepare` still supports `(prepare source)` and now returns `:workflow`; `:source-path` records exact source bytes and a canonical physical path; `:base-dir` supports an in-memory root; roots are ordered ID/path records with duplicate-ID rejection; source and plan digests change for meaningful changes; source whitespace changes the source digest/closure fingerprint even when the prepared graph is equal; physical checkout paths do not change `:fingerprint`; and invalid graphs still produce diagnostics without writes. With synthetic index values, prove that adding/changing a logical alias or exact reference record changes `closure-fingerprint`; recursive alias discovery and resolution remain explicitly deferred to ITER-0005.

Assert the exact root shapes:

```clojure
{:format-version 1
 :fingerprint string?
 :root-plan-id "workflow://root"
 :plans {"workflow://root"
         {:graph (:graph prepared)
          :plan-sha256 string?
          :source-sha256 string?
          :primary-plan-id "workflow://root"
          :references []}}
 :index {:format-version 1
         :root-plan-id "workflow://root"
         :sources vector?
         :plans vector?}}
```

- [ ] **Step 2: Run the root-capture and lifecycle files and verify RED**

Run separately (lgx accepts one test path):

```bash
LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/workflow_recovery_contract_test.lg
LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/lifecycle_contract_test.lg
```

Expected: FAIL because prepare returns no workflow bundle.

- [ ] **Step 3: Implement root source capture**

Add `workflow/root-bundle source graph options`. Normalize and validate `:workflow-roots`, resolve existing source paths with `os/canonical-path`, set `workflow://root` as root/primary ID, leave `:references []`, build the sorted persisted index, then hash `canonical-edn` of the index. Retain diagnostic physical records outside `:index`, for example under `:source-records`, so they never affect the fingerprint. Do not read child files in ITER-0004.

Update `pipeline/prepare` to parse/transform/validate once and attach `(workflow/root-bundle dot-source prepared-graph options)`. Preserve the exact graph object in both top-level `:graph` and the root plan.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the command from Step 2.

Expected: both files pass with existing lifecycle call counts unchanged.

- [ ] **Step 5: Commit**

```bash
git add src/attractor/workflow.lg src/attractor/pipeline.lg test/attractor/workflow_recovery_contract_test.lg test/attractor/lifecycle_contract_test.lg
git commit -m "feat(pipeline): capture prepared root workflows"
```

### Task 3: Publish bundles atomically before execution

**Files:**
- Modify: `src/attractor/workflow.lg`
- Modify: `src/attractor/pipeline.lg`
- Test: `test/attractor/workflow_recovery_contract_test.lg`
- Test: `test/attractor/lifecycle_contract_test.lg`

- [ ] **Step 1: Write failing publication-order tests**

Use a fresh temporary logs root for every case. Prove: invalid preparation and throwing `:on-prepared` write nothing; source/plan content precedes `workflow/manifest.edn`; the manifest is last and uses EDN; existing identical content is reused; mismatched content fails; a lock without a manifest yields `:workflow_publication_incomplete`; two publishers cannot enter the critical section together; UUID temporary names do not collide; `:on-published` sees an existing verified manifest; callback failure prevents engine events but leaves a reusable bundle; retry calls the callback again; and an existing nonidentical manifest yields `:workflow_already_published`.

- [ ] **Step 2: Run focused publication tests and verify RED**

Run the two focused commands from Task 2, Step 2 separately.

Expected: FAIL because publication and `:on-published` do not exist.

- [ ] **Step 3: Implement publication and the prepared execution seam**

Add these workflow functions:

```clojure
(workflow/publish! bundle logs-root)
(workflow/read-manifest! manifest-path)
(workflow/verify-published! run-root checkpoint-fingerprint)
```

`publish!` creates `<logs-root>/workflow`, acquires `.publish.lock` with a non-`-p` `mkdir` subprocess, writes sibling `.tmp-<random-uuid>` files, and uses `os/rename`. It verifies a target before reuse, writes `manifest.edn` last, and removes only the exact empty lock directory after commit. Every catch path deletes only temp files it created; it never recursively removes the workflow or run root.

Add public `(pipeline/execute-prepared prepared options)`. It raises diagnostics, validates format/fingerprint/root graph equality through workflow utilities, derives `:workflow-fingerprint` from the verified bundle and exact `:workflow-manifest "workflow/manifest.edn"`, injects both into engine options, strips all other wrapper-only options, calls `engine/run-pipeline`, and attaches diagnostics. Refactor `pipeline/run` into:

```clojure
(let [prepared (prepare dot-source options)
      diagnostics (validation/raise-on-errors (:diagnostics prepared))
      _ (when-let [f (:on-prepared options)] (f prepared))
      logs-root (or (:logs-root options)
                    (str "attractor_runs/run_"
                         (System/currentTimeMillis) "-" (random-uuid)))
      manifest-path (workflow/publish! (:workflow prepared) logs-root)
      _ (when-let [f (:on-published options)] (f prepared manifest-path))]
  (execute-prepared (assoc prepared :diagnostics diagnostics)
                    (assoc options :logs-root logs-root)))
```

Ensure wrapper callbacks and preparation options are dissociated before the engine call.

Each no-options public run allocates a fresh root as shown, preventing immutable-manifest collisions. An explicit `:logs-root` is retained exactly so a caller can retry the same publication after `:on-published` failure. Add a test that two sequential no-options runs with different sources both execute and publish to distinct roots. Keep low-level `engine/run-pipeline`'s existing `run_latest` default unchanged.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the command from Step 2.

Expected: publication/lifecycle files pass, including callback failure and retry.

- [ ] **Step 5: Commit**

```bash
git add src/attractor/workflow.lg src/attractor/pipeline.lg test/attractor/workflow_recovery_contract_test.lg test/attractor/lifecycle_contract_test.lg
git commit -m "feat(workflow): publish immutable run bundles"
```

## Chunk 2: Checkpoints, Pinned Resume, and Entrypoints

### Task 4: Preserve workflow identity in every checkpoint

**Files:**
- Modify: `src/attractor/context.lg`
- Modify: `src/attractor/engine.lg`
- Test: `test/attractor/context_test.lg`
- Test: `test/attractor/engine_test.lg`
- Test: `test/attractor/workflow_recovery_contract_test.lg`

- [ ] **Step 1: Write failing checkpoint tests**

Round-trip `:workflow_fingerprint`, exact relative `:workflow_manifest`, and `:current_fidelity`; prove legacy EDN and JSON checkpoint reads still work. Run a successful and a failed pipeline and assert every newly written checkpoint contains the supplied workflow identity. Confirm an engine call without workflow options retains its old checkpoint shape.

- [ ] **Step 2: Run checkpoint tests and verify RED**

Run separately:

```bash
LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/context_test.lg
LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/engine_test.lg
LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/workflow_recovery_contract_test.lg
```

Expected: FAIL because `save-checkpoint` drops all three fields.

- [ ] **Step 3: Implement lossless optional checkpoint fields**

Build `checkpoint-data` with the current required keys and conditionally associate only present optional keys. Normalize keyword and legacy string keys in `load-checkpoint`. In both checkpoint construction sites in `engine.lg`, conditionally copy `:workflow-fingerprint` and `:workflow-manifest` engine options to checkpoint keys `:workflow_fingerprint` and `:workflow_manifest`; retain `:current_fidelity` at the stage checkpoint and final checkpoint when known.

- [ ] **Step 4: Run checkpoint tests and verify GREEN**

Run the command from Step 2.

Expected: all focused tests pass, including unchanged legacy fixtures.

- [ ] **Step 5: Commit**

```bash
git add src/attractor/context.lg src/attractor/engine.lg test/attractor/context_test.lg test/attractor/engine_test.lg test/attractor/workflow_recovery_contract_test.lg
git commit -m "feat(checkpoint): retain pinned workflow identity"
```

### Task 5: Verify and resume the captured graph with drift evidence

**Files:**
- Modify: `src/attractor/workflow.lg`
- Modify: `src/attractor/pipeline.lg`
- Test: `test/attractor/workflow_recovery_contract_test.lg`
- Test: `test/attractor/engine_test.lg`

- [ ] **Step 1: Write failing pinned-resume tests**

Launch a deterministic handler graph, stop after a checkpoint, then mutate, delete, and make the original source invalid. Resume must execute the captured root graph and never parse current bytes. Assert exact `:changed`, `:missing`, `:unreadable`, and `:relocated` maps; sorted changes; exact `workflow_drift` diagnostic message; drift event immediately before `:pipeline.started`; no drift for the same resolved path/bytes; `:check-current? false` suppression; and a root-only `:current-source-path` override.

Corrupt each source, plan, manifest fingerprint, checkpoint fingerprint, format version, and root plan ID separately. Assert `:workflow_snapshot_missing` or `:workflow_snapshot_corrupt` with identifying data before any engine event/handler. Reject absolute, escaping, and alternate `:workflow_manifest` values.

- [ ] **Step 2: Run resume tests and verify RED**

Run the workflow-recovery and engine test files separately.

Expected: FAIL because public `pipeline/resume` does not exist.

- [ ] **Step 3: Implement verified loading and pinned resume**

`workflow/verify-published!` must derive run root from the checkpoint parent, require manifest path exactly `workflow/manifest.edn`, EDN-read and version-check the manifest, verify every named file digest and decoded graph plan digest, reconstruct the runtime root plan, recompute the index fingerprint, and return the verified prepared result. Never accept a graph or source from options.

Add `(workflow/current-drift source-records options)` returning sorted change maps. Add public `(pipeline/resume checkpoint-path options)` that loads the checkpoint, verifies the bundle, computes optional drift, wraps `:on-event` to emit the one drift event before passing control to `engine/resume-pipeline`, passes workflow checkpoint options forward, passes the run root derived from the checkpoint parent as exact `:logs-root`, and attaches the exact warning diagnostic to the returned Outcome. Add an assertion that resumed checkpoint/status/artifact writes remain beneath that captured run root and do not appear under `attractor_runs/run_latest`.

- [ ] **Step 4: Run resume tests and verify GREEN**

Run the command from Step 2.

Expected: focused resume and low-level engine compatibility tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/attractor/workflow.lg src/attractor/pipeline.lg test/attractor/workflow_recovery_contract_test.lg test/attractor/engine_test.lg
git commit -m "feat(pipeline): resume pinned workflow snapshots"
```

### Task 6: Route CLI and server through the durable lifecycle

**Files:**
- Modify: `src/attractor/cli.lg`
- Modify: `src/attractor/server.lg`
- Test: `test/attractor/cli_test.lg`
- Test: `test/attractor/server_test.lg`
- Test: `test/attractor/lifecycle_contract_test.lg`
- Test: `test/attractor/workflow_recovery_contract_test.lg`

- [ ] **Step 1: Write failing entrypoint tests**

CLI run must pass `:source-path dot-file` into `pipeline/run`. CLI resume must require only `--checkpoint`, accept an optional positional DOT path as `:current-source-path`, call `pipeline/resume` exactly once, and never call parser/transforms/low-level engine directly. Mutation-sensitive CLI evidence must launch with a path, change/remove that file, and observe drift while captured behavior executes. Server POST must not register or return 201 before `workflow/manifest.edn` exists; it must register exactly once from `:on-published`; publication failure must leave no active registry entry; and retry/idempotent callback behavior must not duplicate state.

- [ ] **Step 2: Run entrypoint tests and verify RED**

Run the CLI, server, lifecycle, and workflow-recovery test files as four separate `lgx test <path>` commands.

Expected: FAIL because CLI parses current DOT and server registers in `:on-prepared`.

- [ ] **Step 3: Implement CLI/server handoff changes**

In `cmd-run`, add `:source-path dot-file` beside its already-fresh explicit `:logs-root`. Change help to `resume [dotfile] --checkpoint <path>`. Build the same registry options as today, conditionally add `:current-source-path`, and call `pipeline/resume`. Remove parser/transform resume work.

Rename the server callback to `on-published`, accept `[prepared manifest-path]`, verify the manifest exists before one compare-and-set registration, store workflow fingerprint/manifest in the active record, then deliver the preparation signal. Keep `:on-prepared` only for any synchronous validation gate that does not publish server state.

- [ ] **Step 4: Run entrypoint tests and verify GREEN**

Run the command from Step 2.

Expected: all entrypoint and lifecycle tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/attractor/cli.lg src/attractor/server.lg test/attractor/cli_test.lg test/attractor/server_test.lg test/attractor/lifecycle_contract_test.lg test/attractor/workflow_recovery_contract_test.lg
git commit -m "feat(entrypoints): use published workflow recovery"
```

## Chunk 3: Scenario Closure and Release Evidence

### Task 7: Close ITER-0004 with mutation-sensitive evidence

**Files:**
- Modify: `test/attractor/workflow_recovery_contract_test.lg`
- Modify: `docs/superpowers/iterations/behavior-corpus.md`
- Modify: `docs/superpowers/iterations/progress.md`
- Modify: `docs/superpowers/iterations/roadmap.md`
- Modify: `docs/superpowers/iterations/requirements/attractor.md`

- [ ] **Step 1: Audit the scenario against every design proof obligation**

Check off SHA-256 goldens, Unicode/numeric cases, synthetic-index alias/reference sensitivity (recursive alias discovery remains ITER-0005), checkout independence, whitespace sensitivity, exact unsupported paths, roots/symlinks, no-write gates, manifest-last order, concurrency/collision/callback recovery, server handoff, checkpoint compatibility, path confinement, all drift states/event order, captured behavior, corruption/missing failure-before-execution, and CLI routing. Add any missing focused test before the marker.

- [ ] **Step 2: Add the exact completion marker only after focused proof passes**

Append exactly:

```clojure
;; SCN-PINNED-RECOVERY COMPLETE
```

- [ ] **Step 3: Run focused, impacted, sentinel, and AOT gates**

Run sequentially:

```bash
rg -q '^;; SCN-PINNED-RECOVERY COMPLETE$' test/attractor/workflow_recovery_contract_test.lg
LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/workflow_recovery_contract_test.lg
LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/context_test.lg
LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/engine_test.lg
LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/lifecycle_contract_test.lg
LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/cli_test.lg
LGX_LG=/Users/ndn/development/let-go/lg lgx test test/attractor/server_test.lg
LGX_LG=/Users/ndn/development/let-go/lg lgx test
LGX_LG=/Users/ndn/development/let-go/lg lgx build
```

Expected: every command exits 0; record exact test/assertion totals and AOT output in `progress.md`.

- [ ] **Step 4: Run the iteration audit workflow**

Use `auditing-progress` for deep current-scenario evidence, impacted seams, and the sentinel corpus. Resolve every correctness finding and rerun the affected gate. Do not treat a skipped or marker-only test as passing evidence.

- [ ] **Step 5: Update iteration ledgers**

Mark ATTR-CP-02 and SCN-PINNED-RECOVERY done in ITER-0004, mark roadmap ITER-0004 complete, advance progress to ITER-0005, and leave ATTR-COMPOSE-01 pending. Include the final commit IDs and proof totals.

- [ ] **Step 6: Commit the audited iteration**

```bash
git add test/attractor/workflow_recovery_contract_test.lg docs/superpowers/iterations
git commit -m "docs(iterations): close pinned workflow recovery"
```

- [ ] **Step 7: Integrate and publish the public checkpoint**

From the main worktree, fast-forward or merge the reviewed ITER-0004 branch without deleting `.worktrees`, rerun the full suite and AOT on main, push `main` to `origin`, then verify the remote commit with `git ls-remote origin refs/heads/main`. Do not remove the worktree unless the user asks.

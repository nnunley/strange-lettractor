# Offline Model Catalog Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development
> through the existing implementing-tasks iteration workflow. Steps use checkbox
> syntax for tracking. Do not start this implementation while another implementer
> owns an active task in this workspace.

**Goal:** Satisfy unified-LLM §2.9's independently updateable offline data-file
requirement while preserving catalog lookup behavior and standalone builds.

**Architecture:** Move the existing catalog vector, unchanged, into sibling
`src/attractor/models.edn`. An internal macro in `models.lg` reads that data at
source compilation and emits it as quoted constant data; all public lookup
functions retain their current interface and ordering. Source installations
include both files, and standalone binaries embed the catalog present at build
time. Updating a binary's catalog requires rebuilding it.

**Tech Stack:** let-go 1.13+, lgx 0.3.2, EDN, clojure.test, existing public model
lookup functions and subprocess test infrastructure.

---

Status: plan review approved; implementation not started. This is an original
spec packaging repair, not module publication, JVM portability, a catalog
download service, runtime hot reload, or provider/auth configuration work.
Use gpt-6-luna for this bounded extraction. Preserve all other working-copy
changes and leave commits/integration to the root coordinator.

The feasibility probe is documented in
[`catalog-refresh-plan.md`](../iterations/catalog-refresh-plan.md). A dependency
macro using `*file*`, `edn/read-string` and `(list 'quote data)` successfully
loaded sibling data from another cwd and embedded it in a standalone binary.
The root independently repeated both modes after the original source path was
moved away. That experiment established embedding feasibility; the loader below
uses `edn/read-all-string` to also reject trailing malformed or extra forms.
This avoids project resource-path requirements and generators.

## Chunk 1: Canonical catalog data with source and binary proof

### Task 1: Prove data-only updates reach the public lookup functions

**Files:**
- Create `test/attractor/model_catalog_packaging_test.lg`.
- Read `src/attractor/models.lg` and `test/harness/runtime.lg`.

- [ ] Map §2.9 to the actual public seams: `get-model-info`, `list-models`,
  `get-latest-model`, source dependency loading, and bundled execution.
- [ ] Write a failing data-update scenario. In a unique temporary source tree,
  copy the real `models.lg` and write a sibling `models.edn` by serializing the
  currently loaded public `catalog` value; this fixture works before the project
  has its own EDN file. Change only the first record's `:display_name` to a unique
  marker in that temporary EDN. Keep its actual ID/provider and all other fields. Run a small
  consumer from a different cwd with only that temporary source root on its
  source path. Assert public `get-model-info` sees the new marker, and the
  original project catalog remains untouched. Use safe argument quoting and
  bounded joined subprocess execution through existing test infrastructure.
- [ ] Add an ordinary source-load check that the public `catalog` equals the
  parsed canonical data. Leave alias/filter/capability semantics to the existing
  consumer tests listed below; do not mirror lookup logic, assert a fixed
  discovered-test/model count, or duplicate the whole table in new assertions.
- [ ] Run `lgx test test/attractor/model_catalog_packaging_test.lg` and observe
  the old literal ignoring the edited EDN: the lookup returns its original name
  instead of the marker. The canonical-file assertion may also fail; the lookup
  mismatch supplies substantive behavior RED before implementation.

### Task 2: Extract data and embed it without changing lookups

**Files:**
- Create `src/attractor/models.edn` (only the existing data vector and comments).
- Modify `src/attractor/models.lg` (data-loading macro; existing lookup logic).

- [ ] Move the current `def catalog` vector into `models.edn`, preserving values,
  types, record order, aliases, capability flags and source links exactly. Do
  not refresh model facts or selection policy during this task. Before moving
  it, retain the current public `catalog` value as EDN in the task's temporary
  evidence directory; compare the extracted data to that snapshot afterward.
- [ ] Require `[clojure.edn :as edn]` and replace the literal initializer with
  a private macro expansion. The proven shape is:

  ```clojure
  (defmacro ^:private embedded-catalog []
    (let [source *file*
          data-path (str (subs source 0 (- (count source) 3)) ".edn")
          forms (edn/read-all-string (slurp data-path))
          data (first forms)]
      (when-not (and (= 1 (count forms)) (vector? data) (every? map? data))
        (throw (ex-info "Model catalog must contain one vector of model maps"
                        {:path data-path})))
      (list 'quote data)))

  (def catalog (embedded-catalog))
  ```

  This namespace is a `.lg` file; the sibling path is derived at macro expansion,
  never from the caller's cwd. The root verified that the existing `clojure.edn`
  namespace exposes `read-all-string` and rejects a malformed trailing form;
  unlike `read-string`, this reads the entire canonical file. Keep the macro
  private and the existing public `catalog` var and functions unchanged. A
  missing or malformed canonical file must fail source compilation clearly,
  rather than silently reverting to stale hardcoded data.
- [ ] Rerun the focused scenario. Confirm editing only the copied EDN changes
  the public lookup result from another cwd. Restore nothing in the project:
  every test mutation belongs to its own temporary tree and is cleaned in
  `finally` after collecting diagnostics.

### Task 3: Prove standalone behavior and document the update contract

**Files:**
- Extend `test/attractor/model_catalog_packaging_test.lg`.
- Modify `docs/provider-model-audits.md` and `docs/verification.md` with the
  catalog's update/build contract and reproduction command.
- Root updates iteration requirements/scenarios/corpus and status artifacts.

- [ ] Compile the consumer of the temporary real namespace and modified EDN
  into a unique binary with `lg -b`, without resource flags. Move the copied
  source/data tree aside and run the binary from another directory. Require
  the same public lookup marker and successful exit; this must exercise the
  actual namespace, not a separately reimplemented loader.
- [ ] Add bounded source-load failure cases for missing EDN, an empty file,
  a wrong outer shape, a vector containing a non-map, an extra top-level form,
  and a valid vector followed by malformed trailing content. Require failure
  before a consumer reports successful lookup. Retain
  useful diagnostics and join/clean the subprocesses and temporary paths.
- [ ] Run `lgx test test/attractor/model_catalog_packaging_test.lg`; then run
  the existing catalog consumers with
  `lg -source-paths src:test test/runner.lg attractor.llm-test
  attractor.default-model-contract-test attractor.prompt-metadata-test
  attractor.anthropic-modern-model-contract-test`.
  Expected: zero failures/errors, with unchanged aliases and default ordering.
- [ ] Document that metadata updates edit the standalone EDN; source consumers
  load it with their library, while compiled consumers rebuild to incorporate
  changes. No network access or automatic reload is introduced. Preserve prior
  audit history and clearly distinguish metadata/packaging proof from live access.
- [ ] Hand the settled files and red/green evidence to root for paired spec and
  quality review. Root runs the integrated suite and a fresh standalone project
  CLI before marking the packaging obligation complete. The overall original
  specification goal and native-provider evidence remain separate obligations.

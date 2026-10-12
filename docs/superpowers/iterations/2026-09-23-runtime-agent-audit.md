# Runtime and coding-agent original-spec audit — 2026-09-23

Follow-up: the [2026-09-27 coding-loop audit](../../coding-loop-audit-2026-09-27.md)
verifies the portable-edit repair and records four additional implementation
defects with their subsequent repairs. All fifteen parity runner rows now exist; statements below about missing
runner rows describe September 23. Full live evidence is still incomplete.

Scope: independent read-only inspection of `specs/attractor-spec.md` and
`specs/coding-agent-loop-spec.md`, current runtime/agent code, and relevant
evidence seams. This is a targeted audit, not a completion certification.
No full suite or live-model calls were run. The two reproductions below ran
against the installed `lg` with `-source-paths src`.

## Confirmed original-scope gaps

### A. Spec-only execution environments cannot use built-in editing tools

The coding-agent spec §1.3 (line 52), §4.1 (lines 724–766), and DoD §9.4
(line 1190) promise that consumers can implement `ExecutionEnvironment`
and run the existing tools in another environment. Its file operations are
`read_file`, `write_file`, `file_exists`, and `list_directory`; command and
search methods plus lifecycle/metadata complete the interface.

`src/attractor/profiles.lg:174` requires an additional `:apply_patch` callback
for OpenAI editing, and line 181 calls an additional `:edit_file` callback
for Anthropic/Gemini editing. `execution/make-environment` supplies neither.
The local implementation supplies both, so local-only evidence hides the gap.

Fresh reproduction: construct an in-memory environment with all 12 specified
operations and a file `hello.txt` containing `before\n`; invoke the native
profile registry's editing executor with a valid edit request. Results:

```clojure
{:tool "edit_file"
 :result {:error "TypeError: nil is not a function"}
 :file "before\n"}
{:tool "apply_patch"
 :result {:error "Execution environment does not support apply_patch"
          :category :unsupported-operation}
 :file "before\n"}
```

The exact interface-key set is also recorded in
`test/attractor/environment_contract_test.lg:17`. The existing custom-env
test at line 255 checks an injected command and metadata defaults, not a
read/edit/write task through an unmodified profile. This is an implementation
gap with a missing integration test, not a missing Docker implementation.

Repair must keep file access in the injected environment. It must not silently
read/write the host filesystem when a remote or in-memory environment lacks
the local-only helper callbacks. Patch delete/move require special care:
the original environment interface has no `delete_file` operation.

### B. Runtime Outcome SKIPPED is rejected as a status-file violation

Attractor §5.2 (`specs/attractor-spec.md:1094`) defines `SKIPPED` as proceeding
without recording an outcome. `src/attractor/engine.lg:276` validates runtime
handler outcomes with the same validator as Appendix C's persisted status
file. `src/attractor/status.lg:4` accepts only success/retry/fail/partial_success.

Reproduction:

```sh
lg -source-paths src -e '(require (quote [attractor.parser :as p]) (quote [attractor.engine :as e]) (quote [attractor.handlers :as h]) (quote [attractor.interviewer :as i]) (quote [attractor.context :as c])) (let [g (p/parse-dot "digraph skip { start [shape=Mdiamond]; optional [type=custom.skip]; done [shape=Msquare]; start -> optional -> done; }") r (h/make-handler-registry (i/make-auto-approve-interviewer) nil) root (str "/tmp/attractor-spec-skip-audit-" (System/nanoTime))] (h/register-handler! r "custom.skip" (fn [_ _ _ _] {:status :skipped})) (prn (e/run-pipeline g {:registry r :logs-root root})) (prn (select-keys (c/load-checkpoint (str root "/checkpoint.edn")) [:current_node :node_outcomes :completed_nodes])))'
```

Observed pipeline status `:fail`, category `:status_contract_error`, reason
`Handler for node 'optional' produced neither status.json nor a valid Outcome`.
The checkpoint records `optional` as a failed outcome and never reaches `done`.

Important scope distinction: Appendix C's on-disk enum excludes skipped, and
`status_contract_test.lg:331` correctly tests the file codec's rejection of
`:skipped`. Preserve the status-file contract while separating the wider
runtime Outcome contract. Spec §3.2's generic record-completion pseudocode and
§5.2's special skipped rule need an explicit interpretation; the current
permanent failure is not either meaning of “proceed.” Cover main traversal,
parallel subgraphs, routing, goal-gate state, and checkpoint/recovery semantics.

## Missing authoritative evidence

Coding-agent §9.12 (`specs/coding-agent-loop-spec.md:1249`) explicitly requires
15 rows across OpenAI, Anthropic, and Gemini. The current live runner
`test/live/parity_matrix.lg:43` exposes 10 rows. It has no rows for parallel
calls, steering, reasoning-effort changes, subagent spawn/wait, or loop warnings.
Its session setup at line 35 sets `max_subagent_depth` to 0. Existing component
tests implement and exercise many of these behaviors, so absent matrix cells
must not be reported as absent features.

`test/attractor/agent_parity_matrix_wire_test.lg` scripts the first 8 rows through
all three native adapters. Separate wire tests support steering, reasoning,
and subagents, but the full current-state matrix must still be assembled and
verified. Existing per-model files in `evidence/parity-matrix-evidence/` do not
prove all 45 cells. The Gemini-model OpenRouter artifact does not prove Gemini
native-protocol behavior. This audit did not perform new live credential checks.

## Scope review: proposed schema repair

Implementing real `unevaluatedProperties` and `unevaluatedItems` validation,
including evaluated-location annotations from successful applicators, is
aligned with unified-LLM §4.5 (`specs/unified-llm-spec.md:961`), §4.6 (line 993),
and DoD §8.4 (lines 2030–2031): the public result is parsed and validated, and
parse/validation failure raises `NoObjectGeneratedError`. Silently ignoring
assertion keywords breaks that guarantee. Rejecting whole schema subsets is
not a substitute for the requested semantics.

Required evidence for this repair should include both valid and invalid
composed objects/arrays, successful-branch annotation union, exclusion of
failed-branch annotations, same-instance reference/conditional/dependent
schema propagation, nesting isolation, and public `generate-object` plus
`stream-object` final-result validation. Keep validation errors outside transport
retries as required by §6.6 (`unified-llm-spec.md:1448`). This scope review does
not certify full JSON Schema dialect or reference conformance, and the repair
does not close those independently documented gaps.

## Boundaries

MCP, skills, permission systems, native sandboxing, and automatic compaction
are explicitly outside the coding-agent core spec (§8). Package publication,
JVM Clojure portability, console features, and module extraction suggested in
the preceding architecture review are not substitutions for finishing the
three original specifications. Their current quality does not close or widen
the original completion requirements.

## Repair follow-up: environment editing

The parent authorized repairing finding A after this read-only audit. The
shared v4a operation engine now accepts filesystem callbacks via
`patch/apply-patch-with-files`; the original local entry point uses that same
engine, preserving hunk matching. Native profile tools retain specialized
`:edit_file`/`:apply_patch` overrides and otherwise operate through the supplied
environment's read/write methods. Unmodified OpenAI, Anthropic, and Gemini
sessions now complete a write/read/edit/read sequence on an in-memory
environment exposing only the twelve specified operations.

The generic reader uses optional `:read_text` when available, otherwise
`:read_file(path, nil, nil)`. After independent review exposed a display/raw
ambiguity, the constructor now documents a complete, unformatted read contract
and profile tools own numbering/pagination for standard environments. A legacy
formatted reader declares `:read_file_format :tool` and supplies `:read_text`
or dedicated editing callbacks. Generic editing refuses a marked formatted
reader without raw access before writing. The local environment declares the
marker and retains its established direct API and reader overrides. Optional
`:read_file_tool` provides a custom tool reader independently of raw reads.

For patch deletion/rename, optional `:delete_file` remains authoritative. On
Linux/macOS environments lacking that capability, deletion delegates a quoted
`rm` command to the environment's own `:exec_command`, checks the command result,
and verifies the file was removed. A real filesystem proxy exposing only the
specified interface proves deletion and rename, including literal quote/dollar
sign filenames. There is no host-filesystem fallback. Non-POSIX environments
without a deletion capability refuse delete/rename before patch writes;
the original interface has no portable file-deletion primitive. This
limitation is explicit, not a claim of universal environment implementation.

TDD evidence:

- Initial native-session/portable-edit regression: 3 tests, 45 assertions,
  24 expected failures and no errors before the repair.
- POSIX-delegated deletion regression: 9 tests, 87 assertions, 8 expected
  failures and no errors before adding the command-interface fallback.
- Final focused verification command:
  `lg -source-paths src:test test/runner.lg attractor.environment-edit-portability-test attractor.patch-test attractor.profiles-test attractor.execution-test attractor.execution-cwd-test`
  — **55 tests, 289 assertions, zero failures/errors**.
- `git -c core.fsmonitor=false diff --check` passed.

Additional tests cover exact replace counts, ambiguous/missing/empty old text,
whitespace replacement, fuzzy/multiple hunks, specialized callback precedence,
raw reader precedence, unavailable deletion before writes, failed/no-op
delegated deletion, malformed/escaping paths, missing update targets, and
existing add targets. Finding B and the parity evidence gaps remain separate
work; this follow-up does not certify full specification completion.

Review remediation added tests for actual line-numbered tool output, 2,000-line
default pagination, explicit offset/limit, literal numbered-looking contents,
full-file editing beyond line 2,000, generic Gemini batch reads, and local reader
compatibility. The initial boundary tests failed 25 assertions; the explicit
formatted-reader guard then failed 9 assertions before its repair. Final
verification including both text/image reader suites:

`lg -source-paths src:test test/runner.lg attractor.environment-edit-portability-test attractor.patch-test attractor.profiles-test attractor.read-file-contract-test attractor.read-file-agent-contract-test`

**38 tests, 387 assertions, zero failures/errors.** These focused results are
additional evidence; the parent owns final integrated suite verification.
The further impacted agent/tool-output/local-execution run passed **90 tests,
611 assertions, zero failures/errors**:

`lg -source-paths src:test test/runner.lg attractor.environment-edit-portability-test attractor.agent-test attractor.tool-output-contract-test attractor.execution-test attractor.execution-cwd-test`

Final review caught a missing preflight: a patch adding a file before updating
another could discover unavailable raw access only after the add. The patch
engine now checks raw-read capability for all update operations before any
mutation, alongside its deletion preflight. Add/delete-only patches remain
usable without a raw reader. The new regression failed five assertions before
the fix; final portability/patch/profiles/text-and-image reader verification
passed **40 tests, 397 assertions, zero failures/errors**.

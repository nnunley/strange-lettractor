# Recursive development controller implementation plan

**Goal:** A local model plans a request, recursively divides it until worker
inputs fit their context budgets, compiles the tree to DOT, then executes
plan → code → test → paired adversarial review → integration → return control.

**Architecture:** Separate model suggestions from controller admission. Stable
requirement IDs survive decomposition. The controller measures complete worker
packets and reserves capacity for system/tool instructions, output and tool
continuations. Every branch retains an integration obligation; passing leaves
alone never proves the parent request complete. All workers and reviewers use
fresh owned sessions and explicit artifacts, not unbounded inherited history.

**Tech stack:** let-go, the native unified LLM/agent layer, DOT preparation and
captured subpipelines, hub operations and the existing console.

## 1. Admission and recursive decomposition

- [x] Add `src/attractor/development_plan.lg` and focused regression tests.
- Require explicit context capacity and reserved tokens. Accept a provider token
  counter; label the fallback UTF-8 byte count as a conservative estimate, not a
  measured tokenizer result. A packet admission result is not proof that an
  arbitrarily long tool conversation fits; execution must enforce the reserve.
- Planner callbacks produce either a leaf or child task proposals. Assign stable
  tree IDs in the controller. Children must cover all parent requirement IDs,
  cannot invent IDs, and must have explicit acceptance checks.
- Reject oversized leaves, non-shrinking oversized splits, excessive depth,
  excessive total nodes and excessive fan-out. Preserve parent acceptance and
  requirements as an integration task. Fail atomically: never return a partial
  plan as an admitted tree. Check cancellation before and after model callbacks.

## 2. Local-model planning and DOT compiler

- [x] Add a bounded native model planner adapter with structured output;
  large source context is processed in measured chunks with bounded notes.
  Oversized task metadata remains an explicit blocker; source retrieval during
  coding and integration remains part of execution work.
- [x] Compile admitted trees into a captured file closure. Leaves contain
  planning, coding, executable verification, two independent review branches,
  adjudication and bounded repair routes. Branches execute their children and
  then integration verification/review against the original parent obligation.
- Keep returned task text as escaped data. Validate all generated DOT with our
  preparation API and Kilroy; adjudicate semantic differences rather than alter
  human-choice routing merely to silence a validator.

## 3. Execution, replanning and frontier escalation

- [ ] Add controller-owned handlers. Verification uses actual exit status;
  review verdicts are parsed and validated, not inferred from a successful model
  response. Require both review results and adjudication before advancing.
- [ ] Enforce reviewer tool restrictions, per-stage prompt/tool/response bounds,
  cancellation and fresh context. Save evidence and bounded handoffs atomically.
- [ ] Replan a leaf when new evidence exceeds its budget. Preserve completed
  artifacts and parent requirements, bound repair/replan attempts, and surface
  irreducible tasks. Frontier planning/code/review uses the same contracts and
  explicit escalation policy. Return routine next tasks to the local model.

## 4. Console and end-to-end evidence

- [ ] Expose request → plan preview → execute → evidence → return-control flow.
  Per-subagent context clearing/compression requires actual hub/runtime support;
  fresh task sessions do not claim to implement those controls.
- [ ] Prove nested decomposition, missing requirements, oversized inputs,
  integration failure, disagreeing reviewers, context exhaustion, refusal to
  escalate, cancellation and resume. Run a bounded real local-model journey.

The existing `development-repl.dot` remains a static example. The generated
`examples/recursive-development/` closure demonstrates the recursive compiler.
Neither example satisfies the unchecked execution and console requirements.

## Model option recorded 2026-09-11

The user reports funded OpenRouter access and willingness to use Meta's
discounted contributor tier. Current model:
`openrouter/meta/muse-spark-1.3-contributor`. OpenRouter lists $0.10/M input,
$0.20/M output, a 1,048,576-token window, tool calls and structured output.
Prompts and outputs may be used to improve Meta products.
Source: [OpenRouter model page](https://openrouter.ai/meta/muse-spark-1.3-contributor).

Muse is itself a frontier model; its lower price is not a separate capability
class. Candidate routing: local → Muse Contributor → Anthropic/OpenAI when task
results justify escalation, without claiming a universal quality ordering. This does
not alter the local worker budget, enable account-wide training settings, or
claim that Muse has passed our native agent/structured-output contracts. Live
capability checks and user-selected routing remain part of execution integration.

## Admission API checkpoint

`development-plan/decompose` accepts a task with `:objective`, `:requirements`
(`{:id :text}` records), `:context` and `:acceptance`, a planner callback, and
explicit `:context_window` / `:reserve_tokens`. A supplied `:count_tokens`
function measures the exact `task-packet`; otherwise UTF-8 byte count is labeled
`:utf8-byte-estimate`. Returned leaves have measured packets within budget.
Branches retain the original parent task, which is **not** admitted as a worker
packet: integration must construct and admit its own bounded packet from child
artifacts. Requirement-ID coverage is a structural check, not a semantic proof
that the planner's subtasks or acceptance checks are sufficient.

The callback receives the full task as controller data. A native model adapter
must independently bound what it serializes into a planner prompt; this module
does not make oversized requests safe to send to a model. It performs no model
calls, file publication, DOT generation, execution or context compression.

## Native planner API checkpoint

`development-planner/make-planner` takes a model address and options and returns
an admission-compatible callback. Use it as the second argument to
`development-plan/decompose`. Planner and worker budgets are independent.
Required planner options are `:context_window` and `:reserve_tokens`;
`:max_output_tokens` defaults to 1024 and must fit the reserve.
`:max_notes_tokens` defaults to 512; `:max_calls` defaults to 32 per callback.
Supply `:count_tokens` for the model tokenizer, otherwise UTF-8 bytes are used.
`request-size` measures serialized user-message and response-format content;
the reserve must also cover provider-specific framing and generated output.
It is not a provider token-usage guarantee.

Every call uses native `llm/generate-object` with a fresh prompt, no tools,
no automatic retries and a bounded output. Small sources go straight to a
structured decision. Large sources are processed in sequential measured chunks;
the callback then decides from bounded accumulated notes. Task requirements,
objective and acceptance stay intact in each prompt. Notes are lossy planning
aids: exact chunk coverage proves the input was presented, not that every fact
survived summarization. Originals remain in the admission tree. Worker retrieval
and independent verification still have to establish semantic sufficiency.

`:client` supports native client configuration and deterministic fixtures;
`:cancelled?` interrupts active generation and prevents later calls. Malformed
JSON/schema output, oversized notes, oversized fixed metadata or an exhausted
call limit stops planning. No partial tree is published. The adapter makes no
DOT files, changes no provider accounts and does not enable console compression.

Verification: `make run-development_planner` passes 8 tests / 37 assertions,
including real native-client structured generation with a scripted adapter,
exact Unicode/escaped source chunk coverage, all request sizes, recursive
admission, call/notes limits, invalid output/configuration, and cancellation.
These are deterministic contract tests; no live-model quality claim is made.

Full-suite checkpoint after the adapter: 954 tests / 9078 assertions / zero
failures (`make test`). This does not close the unchecked implementation stages.

## Recursive DOT compiler checkpoint

`development-workflow/compile-plan` takes `[task planner admission-options
compiler-options]`. Use the native planner callback or a deterministic callback.
It first admits the complete tree, then returns `{:tree :sources :prepared}`.
`:sources` maps safe generated names (`task.dot`, `task_0.dot`, ...) to DOT text;
`:prepared` is the validated native captured closure, ready for controller-owned
execution. Compilation performs no filesystem writes or execution. Pass
`:max_repairs` (default 1, allowed 0–4) in compiler options.

Each leaf contains plan → code → test → two parallel reviews → fan-in →
adjudication → evidence publication → exit. Repair attempts are unrolled; a
failed test cannot skip to review or publication. Review failures still reach
adjudication, which must examine both original `parallel.results`. Native fan-in
selection alone is not approval. Each branch executes child subpipelines
sequentially, imports distinct `development.child.<id>` results, then performs
the same stages for integration against its retained original task.

Controller work is represented as tool nodes carrying `development.stage` and
`development.attempt`. Their default command is `false`, so an unconfigured run
fails rather than simulating work. A future controller installs a tool dispatcher
for these stages, admits each complete stage packet, executes real checks,
validates review evidence, and publishes bounded immutable handoffs. Task JSON
in graph attributes is captured data, not an admitted integration prompt.
No model routing or live-worker execution is claimed by this compiler.

The checked-in [root graph](../examples/recursive-development/task.dot) and its
two descendants were generated from the three-level regression fixture. All
three pass native preparation and upstream Kilroy single-file validation (same
commit as `docs/kilroy-validation.md`), zero diagnostics. Kilroy recognizes the
fallback tool shape; this is structural validation, not proof that Kilroy
executes our subpipeline extension or controller stages.

`make run-development_workflow`: 8 tests / 38 assertions. Actual captured
subpipeline execution with scripted stage handlers proves child ordering,
result propagation, finite repairs, failed reviews reaching adjudication,
child failure blocking parent integration, and default execution failure.
Literal quote/backslash/newline task data round-trips through generated DOT.
That last check exposed chained unescaping in the general DOT parser: a
single-pass decoder now preserves escaped backslashes without decoding their
following characters again. Parser regression: RED 2 failures; GREEN 10 tests /
45 assertions. Production handler semantics and live evidence remain pending.

Full-suite checkpoint after compiler/parser work: 963 tests / 9122 assertions /
zero failures. User clarified that existing upstream workflow reuse is the
priority; see [workflow survey](upstream-workflow-survey.md) before extending
the custom controller further.

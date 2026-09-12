# Embedded paired review

`attractor.embedded-review` binds ordinary let-go functions to native pipeline
handlers. Review reports and decisions travel in structured outcomes, without
shell verdict parsing or approval marker files. The example graph is
[`examples/embedded-review.dot`](../examples/embedded-review.dot).

A review function receives `[node ctx graph logs-root]` and returns exactly:

```clojure
{:verdict :approve ; or :revise
 :findings []      ; nonempty for :revise
 :evidence ["Concrete checks/findings from the review"]}
```

Both vectors contain nonblank strings, with at most 64 entries each; a serialized
report is limited to 16 KiB. Evidence text remains a reviewer's assertion: these
wrappers validate the contract, not whether the claimed checks were performed.
The reviewer implementation owns actual tools, model calls and evidence capture.

Bind your own reviewer functions and adjudicator before executing the graph:

```clojure
(require '[attractor.embedded-review :as review])
(require '[attractor.handlers :as handlers])
(require '[attractor.pipeline :as pipeline])
(require '[io :as io])

(def registry (handlers/make-handler-registry))
(handlers/register-handler! registry "review.correctness"
  (review/make-reviewer correctness-review))
(handlers/register-handler! registry "review.requirements"
  (review/make-reviewer requirements-review))
(handlers/register-handler! registry "review.adjudicate"
  (review/make-pair-gate ["correctness" "requirements"] adjudicate-reviews))

(pipeline/execute-prepared
  (pipeline/prepare (io/slurp "examples/embedded-review.dot"))
  {:registry registry :logs-root "attractor_runs/embedded-review"})
```

`correctness-review`, `requirements-review` and `adjudicate-reviews` above are
application-supplied functions, not bundled model implementations. The
adjudicator receives `[{ :reviewer id :report report } ...]` in declared reviewer
order and returns the same report contract. Native LLM structured output returns
string-keyed JSON maps; normalize those into this keyword contract explicitly.

The gate requires exactly two expected, distinct branch IDs, successful branch
execution, two valid reports and a valid adjudication. It accepts only when all
three verdicts approve. An adjudicator cannot waive a reviewer's revise verdict.
Malformed, failed, partial or missing branches do not reach adjudication.
Cancellation is checked before and after callbacks, and failed/cancelled gates
clear previous approval context. Callbacks still own cancellation of their own
active I/O; these checks alone cannot interrupt an arbitrary blocking function.

The fan-out must use `wait_all`; each reviewer must terminate at its shared
fan-in boundary. Keep the adjudication handler on a separate tool-shaped node
after fan-in. Otherwise an absent custom binding on a tripleoctagon could fall
back to the standard fan-in selector and bypass the approval check. The shipped
example instead falls back to `false` if any binding is missing. Custom types
produce expected native `type_known` warnings until bound; preparation cannot
inspect a runtime registry. This is portable DOT syntax with application-specific
bindings, not a workflow every Attractor runtime can execute unchanged.

Verification: `make run-embedded_review` passes 8 tests / 39 assertions through
native parallel execution and direct handler checks. Initial stubs failed 21
assertions; stale-approval checks also failed before explicit clearing was added.
No shell or model is needed for configured gate logic. The tests use scripted
reviewers, so reviewer quality and independent tool restrictions remain unproven.

The imported task-runner now uses these bindings in its primary graph; see
[its integration API](../examples/task-runner/README.md). Shell budget accounting
and the verification subprocess wrapper remain separate migration work, as does
recursive context-budget integration. CLI bindings are described below.

Full-suite checkpoint: 978 tests / 9184 assertions / zero failures. The final
focused 8/39 run also uses the shipped example DOT directly.

## Native model reviewer

`model-review/make-reviewer` supplies the reviewer callback expected by
`task-runner/bind-reviews` or `embedded-review/make-reviewer`:

```clojure
(require '[attractor.model-review :as model-review])

(def correctness-review
  (model-review/make-reviewer "llamacpp/qwen3.8-27b"
    build-review-packet
    {:context_window 16384 :reserve_tokens 2048 :max_output_tokens 1024}))
```

`build-review-packet` is application supplied. It receives
`[node ctx graph logs-root]` and returns a nonblank string containing the task,
relevant source/diff and actual verification evidence. The node's prompt selects
the review lens. Every invocation uses a new native `llm/generate-object` call,
normalizes the JSON report to the keyword contract, and exposes no tools to the
model. It cannot read or modify the repository, run tests, or independently
collect evidence; those responsibilities remain with the packet builder and
execution controller. Use the embedded wrapper to enforce the full report
schema, evidence requirements and report size after generation.

Planner, worker and reviewer context limits are separate. The reviewer measures
serialized message/schema content with `:count_tokens`, defaulting to UTF-8 byte
count as an estimate. The reserve covers model output and provider-specific
framing. Oversized packets fail with `:review_packet_too_large`; they are never
silently truncated. Splitting or retrieving a smaller sufficient evidence packet
remains controller work. Output is bounded by `:max_output_tokens`; automatic
provider retries and tool rounds are disabled. Native client options such as
`:client`, `:timeout` and `:provider_options` may be supplied. Node cancellation
is checked around packet construction and generation and forwarded as the native
abort signal.

`make run-model_review`: 4 tests / 14 assertions through the unified client with
a scripted provider. The stub failed 3 assertions before implementation. The
checks verify fresh structured requests, no tools, output bounds, packet overflow,
invalid measurement, and cancellation before dispatch. Embedded gate regressions
also pass 8/39. No live-model run or quality conclusion is claimed. Native model
adjudication and evidence-packet construction are described below.

## Native model adjudication

`model-review/make-adjudicator` returns a context-aware callback with signature
`[reports node ctx graph logs-root]`. Its packet builder still receives the four
usual execution arguments and supplies the original task and evidence. The
adapter appends the complete ordered reports, measures the combined request,
and uses fresh structured generation with no tools and the node's abort signal.

```clojure
(def adjudicate-reviews
  (model-review/make-adjudicator "llamacpp/qwen3.8-27b"
    build-adjudication-task-packet
    {:context_window 16384 :reserve_tokens 2048 :max_output_tokens 1024}))

(def gate
  (review/make-contextual-pair-gate
    ["correctness" "requirements"] adjudicate-reviews))
```

Use `:adjudicate_with_context adjudicate-reviews` with `task-runner/bind-reviews`.
It is mutually exclusive with the original `:adjudicate` reports-only callback,
which remains supported. The gate still requires approval from both reviewers
and adjudication; a model cannot waive the other reviewers' rejection.

Current checks: model-review 7 tests / 26 assertions; embedded-review 8/39;
task-runner integration 12/41 including its original shell baseline. These cover
context forwarding, cancellation triggered during a native provider call, and
rejecting a combined task-plus-reports packet before dispatch when oversized.
Providers and reviewers are scripted for these tests; live quality is unverified.
CLI/console bindings are now available as described below.

## Native evidence collection

`attractor.review-packet/make-packet-builder` supplies the four-argument callback
accepted by both model adapters:

```clojure
(def build-review-packet
  (review-packet/make-packet-builder
    {:working_dir "/absolute/path/to/repository" :max_bytes 1048576}))
```

The JSON packet contains the task, verification log, HEAD revision, tracked
changes relative to HEAD (including staged and unstaged edits), and untracked
file patches. Runner artifacts under `attractor_runs` are excluded from changes.
The defaults read `attractor_runs/task-runner/task.md` and
`attractor_runs/task-runner/state/verify.log`; override with `:task_file` and
`:verification_file`. An existing Git HEAD is required. Untracked symlinks are
represented as link patches, without following their targets.

Git commands use native owned subprocesses with cancellation and a 30-second
timeout per command. The collector rejects packets above `:max_bytes` and more
than `:max_files` untracked files (default 128). Git output is checked after
capture, so this does not impose a process-memory bound. Two complete collections
must agree; observable drift fails with `:review_packet_changed`. This is not an
atomic snapshot and does not prove that the verification log belongs to the
current revision. Model context admission still applies separately.

Collector tests: 5 tests / 14 assertions covering real Git changes, shell-sensitive
filenames, symlinks, missing/oversized artifacts, cancellation, and workspace drift.

## Stylesheet selection in CLI and console

The CLI installs native `task.review.*` bindings for `run`, `resume`, and
`console`. Models and budgets come from each node after stylesheet resolution:

```css
.review {
  llm_provider: llamacpp;
  llm_model: qwen3.8-27b;
  --context-window: 16384;
  --reserve-tokens: 2048;
  --max-output-tokens: 1024;
}
#adjudicate { --max-output-tokens: 1536; }
```

Put these rules in the DOT graph's `model_stylesheet` attribute and assign
`class="review"` to the two reviewers and adjudicator. The standard model fields
also select different providers/models per role. No separate configuration file
or binding flag is needed. `--model` selects the coding backend separately.
Explicit native reviewers still use their selected providers with `--mock`.

Custom property names use `--` followed by lowercase letters, digits and hyphens.
Values can be quoted strings, identifiers, or unsigned integer literals. They
follow existing selector precedence: explicit node attributes, matching rules
(ID > class > shape > universal, later ties win), then graph attributes. This
extension carries literal values; CSS `var()` interpolation is not implemented.
Unknown ordinary declarations remain syntax errors. Quote custom attribute names
for an explicit DOT override, e.g. `adjudicate ["--reserve-tokens"=4096]`.

The handlers require a model and positive context/reserve budgets and default
output to 1024. Missing or invalid budgets fail before evidence collection or
provider dispatch. Evidence and critique use the process working directory and
the task-runner graph's fixed artifact layout. Each workflow receives a copied
registry; applications can still supply their own callback bindings.

Public CLI coverage executes parallel review, Git collection and adjudication
with scripted provider responses and checks class selection plus ID overrides.
Console and resume share the registry factory but do not yet have independent
configured-review journey tests. Live model quality remains unverified.

The shipped task-runner is also exercised end to end with a real Bash verifier
and Git workspace, checking that all three native calls receive both the changed
code and verifier output before a handoff is published. Model responses and the
coding stages are scripted. This caught duplicate `class` attributes on the two
reviewer nodes: their later `gate` class erased `review`. Use one comma-separated
class list, `class="review,gate"`. The focused binding suite now passes 16 tests /
55 assertions, including the imported shell and collector fixture suites.

Native reviewer outcomes also record `review.evidence_digest`, a SHA-256 digest
computed from the exact supplied packet. The adjudicator requires both digests
to match its current packet before generation and rechecks the packet afterward.
Observed changes fail with `review_evidence_changed` and cannot approve a handoff.
The binding suite now passes 17 tests / 63 assertions, including changes after a
review and during adjudication. This is not an atomic repository lock and does
not establish that an existing verification log was produced for the current code.
Direct application bindings remain responsible for their own evidence provenance.

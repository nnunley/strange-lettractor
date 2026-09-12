# Imported development task runner

[graph.dot](graph.dot) adapts Microsoft's Amplifier task runner for this native
Attractor implementation. It keeps the attempt → executable verification →
paired review and adjudication loop, repeated-failure diagnosis, feedback files, budget decisions and
handoff. [Pinned upstream source and MIT license](../upstream/amplifier/README.md).

Run from the worktree you want the agent to edit. Create two files first:

- `attractor_runs/task-runner/task.md`: the complete request, requirements,
  judgment criteria, constraints and any repository instructions to consult.
- `attractor_runs/task-runner/task.verify.sh`: a Bash verifier that exits zero
  only when the task's mechanical checks pass. For example, run the relevant
  tests with failure-propagating exit codes. The workflow invokes it via Bash;
  executable permission is not required.

The migrated `graph.dot` uses bound let-go review functions. Its
`model_stylesheet` selects reviewer models and context budgets via `.review`
and optional per-node overrides. Set those values to match your providers, then:

```sh
bin/attractor run examples/task-runner/graph.dot --llm --model llamacpp/qwen3.8-27b
```

The same bindings are installed for `console` and `resume`. Reviewer models come
from the DOT stylesheet; `--model` controls the coding backend separately. Even
with `--mock`, explicit native reviewers use their selected providers. Credentials
come from provider configuration. The example uses one local model in three
fresh calls; use ID selectors to assign different models or budgets by role.
See [stylesheet binding details](../../docs/embedded-review.md#stylesheet-selection-in-cli-and-console).

For the preserved single-critic shell variant, after building the current binary,
run with your configured local provider:

```sh
bin/attractor run examples/task-runner/shell-review.dot --llm --model llamacpp/qwen3.8-27b
```

Use an absolute graph/binary path when targeting a different repository. The
working directory is the target worktree. The interactive CLI handles the budget
gate; `--auto-approve` selects its first choice, abandonment. Console human-gate
support remains limited as described in the root README.

`ATTRACTOR_TASK_MAX_ITERATIONS` selects the initial verification budget (default
6, range 1–15). Continuing at the human gate adds 3, capped at 15. A request to
continue at the cap fails explicitly. Verification has a native 30-minute
process timeout; other shell stages have 30 seconds, model stages 20 minutes.

Artifacts live in `attractor_runs/task-runner/state/`: brief, verification log,
convergence records, critique, feedback, diagnosis/postmortem and `SHIPPED.md`.
A successful run returns an **uncommitted handoff**. A new run refuses to reuse
an existing state directory. Use a separate worktree or archive the old state
before starting a different task; use native checkpoint resume for interruption
rather than launching the graph again.

## Adaptation from upstream

- Route on exact `tool.output`, which these shell nodes emit as a single token.
  No new global parameter expansion or `tool.last_line` alias was added.
- Replace parameter placeholders with the task paths above and use the current
  working directory. Replace destructive `.ai` initialization with a fresh state
  directory check; preserve existing artifacts.
- Return a handoff instead of automatically committing, changing branches or
  editing Git configuration. Model instructions remain instructions, not an
  enforced tool permission boundary.
- Preserve explicit failing terminals as native failures without routing them
  through a successful exit. Retain the graph's abandonment retry target as a
  goal-gate backstop.
- Require the final critique line to be exactly `VERDICT: SHIP`. Clear the prior
  critique after a successful verification before soliciting a fresh one.
- Persist the attempt counter before launching verification so interrupted
  checks also consume budget. Use native process timeouts and `shasum -a 256`
  instead of GNU `timeout` and `md5sum`.
- Use fresh `truncate` fidelity and explicit feedback artifacts. This does not
  implement interactive context clearing/compression or measured stage budgets.

## Evidence and remaining scope

`make run-imported_task_runner`: **7 tests / 23 assertions / zero failures**.
The fixture executes the real shell stages and native engine with scripted model
responses. It covers a successful handoff, repeated failures leading to diagnosis
and abandonment, rejection of `VERDICT: NOT SHIP`, preservation of old artifacts,
the hard budget cap, and interrupted checks consuming attempts. The unadapted
source failed 10 assertions; the timeout-counter regression failed separately
before its correction. No live-model run is claimed.

The preserved `shell-review.dot` uses one critic. The primary `graph.dot` now
uses embedded paired review as described below. Local-to-frontier routing,
immutable acceptance checks, recursive context subdivision and per-stage
execution budgets remain separate work. The verifier is not an immutable
security boundary here: this workflow checks the current task verifier, and its
model instructions forbid weakening it. Stronger enforcement belongs in the
controller rather than a claim based on prompt text.

## Embedded paired-review variant

`graph.dot` replaces the shell critique/verdict stages with correctness and
requirements reviewers running in parallel, then native adjudication. Supply
application review functions using the [embedded report contract](../../docs/embedded-review.md):

```clojure
(require '[attractor.task-runner :as task-runner])
(require '[attractor.pipeline :as pipeline])
(require '[io :as io])

;; coding-registry already has the real coding backend, tools and interviewer.
(def registry
  (task-runner/bind-reviews coding-registry
    {:correctness correctness-review
     :requirements requirements-review
     :adjudicate adjudicate-reviews
     :state_dir "attractor_runs/task-runner/state"}))

(pipeline/execute-prepared
  (pipeline/prepare (io/slurp "examples/task-runner/graph.dot"))
  {:registry registry :logs-root "attractor_runs/task-runner/logs"})
```

The registry is copied; the caller's existing bindings remain unchanged. This is
a library integration: the function names above are supplied by the application,
and automatic CLI/console binding discovery is not implemented. Starting the
primary graph without bindings fails at review; it cannot silently approve via
a default model handler. The custom types produce expected preparation warnings.

Only successful execution and approval from both reviewers plus adjudication
can reach packaging. A revise verdict is never waived by adjudication. Refusals
are counted in checkpointed context; three refusals route to postmortem. Invalid
or failed reports route there immediately without adjudicating missing evidence.
The gate atomically replaces `state/critique.md` for human/model consumption;
structured reports and decisions live in engine status/checkpoint artifacts.
It does not parse that Markdown to make a decision. Failure to publish the
readable report blocks packaging. Review outcomes are not appended to the old
shell convergence JSONL; consult the adjudication stage's status for review data.

`make run-task_runner_review`: 11 tests / 39 assertions, comprising the original
7 shell-variant tests and 4 paired-variant tests (16 additional assertions).
These execute real verification subprocesses and native parallel handlers with
scripted reviewers. They prove approval, three-round refusal across restarts,
invalid-report rejection, and artifact-write failure routing. Live reviewer
quality and read-only tool restrictions are still unverified. The model prompts
request read-only review, but the bound implementations must enforce permissions.

Full-suite integration checkpoint: 982 tests / 9200 assertions / zero failures.

Native model adjudication can be supplied as `:adjudicate_with_context` instead
of `:adjudicate`; the callback receives `[reports node ctx graph logs-root]`,
including cancellation. See [native review and adjudication](../../docs/embedded-review.md).
Latest focused integration: 12 tests / 41 assertions, including the shell baseline
and context-aware binding. Do not specify both adjudicator options.

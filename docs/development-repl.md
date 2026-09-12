# Local development loop with frontier escalation

[development-repl.dot](../examples/development-repl.dot) runs bounded native
agent turns against your repository. The console is the interactive frontend;
the graph supplies task selection, verification, local repair, escalation and
review. It starts locally and returns to local execution for each new task.

```text
task → local work → verify ──pass──→ your review → next task / finish
                     │
                    fail
                     ↓
                local repair → verify
                                 │ fail
                                 ↓
                        approve frontier call
                                 ↓
                        GPT worker → verify
                                       │ fail
                                       ↓
                             approve independent worker
                                       ↓
                              Claude worker → verify → review / blocked
```

Escalation also handles model-call errors. Each tier runs at most once before
the next decision, with one local repair attempt. Human choices can start another
round. Choosing Q ends the workflow normally even when the task is unresolved;
pipeline success on that path means you chose to stop, not that verification passed.

## Run it

From this repository, prepare the current request:

```sh
mkdir -p attractor_runs/repl
cp examples/development-task.md attractor_runs/repl/task.md
# Edit attractor_runs/repl/task.md to describe your request and acceptance checks.
make build
bin/attractor console --llm
```

In the console:

```text
/run examples/development-repl.dot
/answer L
```

Use the choices printed at each question. `/answer F` approves the GPT worker;
`/answer O` approves the Claude worker. `/answer Q` returns to the ordinary
console. At review, N starts the next task after you edit the task file. Ordinary
console messages go to its native chat session, **not** to the running workflow;
put workflow instructions in the task file. `/focus <run-id>` selects which
workflow receives answers when more than one is waiting. `/cancel` cancels the
focused run and its active work.

For a standalone interactive run:

```sh
bin/attractor run examples/development-repl.dot --llm
```

Do not pass `--model` or `--provider` when starting this workflow or its console:
those are global overrides and would replace the graph's per-node routing.
Do not use `--auto-approve` for this interactive loop. Frontier gates put Q first,
so automatic first-choice approval does not spend on frontier calls.

## Models and verification

The three stylesheet entries at the top of the DOT select:

| Role | Provider | Model |
|---|---|---|
| Local implementation and repair | `llamacpp` | `qwen3.8-27b` |
| Frontier escalation | `openrouter` | `openai/gpt-5.2` |
| Independent escalation | `openrouter` | `anthropic/claude-opus-4.6` |

These use registry IDs already configured in this checkout. Change the entries
to models available on your endpoints; no credentials are embedded in the DOT.
The frontier choices are examples, not an assertion that one universally ranks
above the other. See the vendor descriptions of [GPT-5.2](https://openai.com/index/introducing-gpt-5-2/)
and [Opus 4.6](https://www.anthropic.com/news/claude-opus-4-6).

Verification defaults to `make test` in the process working directory. Override
it before starting the console, for example:

```sh
export ATTRACTOR_REPL_VERIFY='make run-retry_predicate && make run-llm'
bin/attractor console --llm
```

Use checks that demonstrate your task's acceptance criteria. The verifier saves
complete output in `attractor_runs/repl/verify.log`, prints its final 80 lines,
and preserves the command's exit code for routing. Agent turns have 20-minute
deadlines and verification has a 30-minute deadline. The agents may run their own
focused checks first. Only one development workflow should edit this workspace
and its shared task/handoff/log files at a time.

## Context lifecycle

Every worker node uses `fidelity="truncate"`: a **new native session** with the
goal and run ID, then its explicit stage prompt. No full-history thread is reused.
The request, actual files and diff are authoritative. Workers write a compact
handoff into `attractor_runs/repl/handoff.md`; repair and frontier workers read it
alongside the verification log. This is an explicit cross-turn summary, not
automatic in-session context compression. Edit the handoff if it becomes stale.

The console currently has **no per-agent `/compact` or `/clear` command**. It also
does not expose these workflow worker sessions or nested subagents as independently
addressable console sessions. `/new` opens a new top-level chat; it does not reset
a pipeline worker or subagent. Clearing/compacting a running subagent therefore
is not a capability of this DOT. Long individual turns can still hit context
limits before they produce a handoff. Per-agent context controls require runtime
and hub operations with turn ownership checks, plus console commands.

## Evidence

`make run-development_repl` prepares the real DOT and exercises local success,
local repair, paid-call refusal, both escalations, exhausted verification and
return to local on the next task. It uses deterministic worker outcomes and human
answers, so it performs no model calls or repository edits. Live local/frontier
execution of this example has not been performed.

The focused suite passes 2 tests / 26 assertions. A separate isolated execution
of the real verification ToolHandler also confirmed exit 7 routes as failure,
exit 0 routes as success, and both preserve the complete verification log.

# Future work

User-requested extensions beyond the StrongDM Attractor conformance baseline.
Each entry is a design question to settle before implementation, not a
selected format or API, and none replaces a conformance iteration in
`superpowers/iterations/roadmap.md`. Items are listed in the order they were
raised; the roadmap decides scheduling.

## User configuration (requested 2026-09-08)

Today the only user configuration is the process environment plus `.env`
(`dotenv`): provider credentials and base URLs, as the unified LLM spec §2.2
prescribes for `Client.from_env()`. The specs describe a library whose host
application owns all other settings in code, and never contemplated a
standalone product with a console, agent defaults, local model endpoints or
per-user preferences. Everything else is currently repeated as CLI flags on
every invocation: `--model provider/name`, `--alias`, `--agent-cwd`,
`--agent-model`, `--agent-sandbox`, `--agent-permission-mode`, the hub's
per-agent commands, and the llama.cpp endpoint.

Progress 2026-09-09: the provider layer exists (`src/attractor/providers.lg`,
`attractor.edn` at the project root or `~/.config/attractor/`, data-only
entries with protocol, base URL, key variable name and model-discovery
toggle, precedence built-ins < user < project < environment < explicit,
`attractor providers` to show effective values with sources). Everything
below that is not about providers remains open.

The design session should settle:

- **Sources and precedence.** A `.edn` settings file read with the Clojure
  reader superset (the project's reader decision), at a user location
  (`~/.config/attractor/` or `$XDG_CONFIG_HOME`) and at the project root,
  layered as built-in defaults, user file, project file, environment, then
  flags. Keep credentials in the environment or `.env`; the file may name an
  environment variable, never contain a secret.
- **Contents.** Model aliases and the default model (`provider/name`), provider
  base URLs for local services, default agent options per agent name (cwd,
  model, tools, permission mode, sandbox, approval policy, timeout), agent
  commands (argv per agent, currently trusted hub startup configuration),
  console aliases, and console presentation choices (line or TUI, poll
  interval). Workflow configuration stays in DOT; `model_stylesheet` is not
  duplicated.
- **Trust.** Reading configuration must not evaluate it: data only, validated
  against a schema with explicit errors for unknown keys, and no
  reader-embedded code. Agent commands and sandbox/permission defaults widen
  what an agent may do, so a project file must not silently escalate over the
  user file; decide whether such keys are user-only or require confirmation.
- **Discovery and visibility.** `attractor config` (or `/config` in the
  console) shows the effective configuration with each value's source, and the
  console's `/alias` can persist to the user file explicitly rather than only
  for the session.
- **Relationship to packets.** Executable packets and skill packages (below)
  will carry their own manifests; user configuration is the smaller, earlier
  layer and should not grow into a package manager.
- **Evidence.** Precedence tests over all five layers, secret-free file
  validation, unknown-key and malformed-file errors, a console started with
  only a file and no flags, and `attractor config` output matching the values
  actually used by a run.

## Provider connection patterns from evener (surveyed 2026-09-10)

Adopted: per-entry auth schemes with protocol defaults, `:auth_header`,
`:credential_headers` that win over the derived header, redaction of
configured credentials from anything written or printed, and resolution
that never requires a credential. Still worth taking, in order:

- A rate-limit wall-clock budget distinct from attempt counting, with a
  shutdown reserve held back from the caller's deadline, so a 429 storm
  waits a bounded time instead of a fixed number of tries.
- A provider-unhealthy short-circuit: repeated stream stalls or hard-cap
  truncations raise a distinct error instead of spending the retry budget.
- Token-minting schemes: Google application-default credentials for Vertex
  and the Codex OAuth record with refresh, each cached per entry and keyed by
  a hash of the credential's identity so a rotated file is noticed. The Codex
  record must never be satisfied by an environment key.

Not adopted: a downloaded model catalogue layered under the registry with a
refresh cache. It makes a provider's effective definition depend on a
network fetch and cache age. A read-only capability catalogue kept apart
from auth would be a separate, smaller change.

## Kilroy's text-to-DOT ingestion and CXDB (requested 2026-09-10)

[Kilroy](https://github.com/danshapiro/kilroy), the Go Attractor
implementation evener was forked from, has two capabilities worth studying.

**Text to DOT (`attractor ingest`).** Kilroy turns English requirements into
a Graphviz pipeline (`kilroy attractor ingest -o pipeline.dot "Solitaire
plz"`) by running the Claude CLI with a `create-dotfile` skill, then feeding
the result to `attractor validate`. Its docs carry a StrongDM
`ingestor-spec.md` that is not in our upstream snapshot; read it first.
Relevant code: `cmd/kilroy/ingest.go`, `internal/attractor/ingest/`, the
skill under `skills/create-dotfile/` (also `.gemini/skills/english-to-dotfile`),
and demo pipelines under `demo/`. Here the pieces already exist: the
`claude` and `codex` agents, the hub's `:agent/run`, and `bin/attractor
validate`. Exploration should settle whether ingestion is a CLI command, a
console command, or itself an Attractor pipeline (draft, validate, repair
until valid), and how validation diagnostics are fed back to the drafting
agent.

**CXDB integration.** CXDB is Kilroy's execution database: typed run events
(run started, stage finished, checkpoint saved, run completed or failed), a
blob store for logs, outputs and archives, and run metadata such as the logs
root and checkpoint pointers written into the same timeline, so a run can
resume from CXDB alone. Kilroy talks to it over a binary msgpack protocol and
HTTP (`internal/cxdb/`, `internal/attractor/engine/cxdb_*.go`,
`scripts/start-cxdb.sh`). Ours keeps the same information in three places:
the hub's in-memory event log, `artifacts/index.edn` on disk, and
`checkpoint.edn`. Exploration should decide whether CXDB becomes an optional
event sink and artifact backend behind the existing event families and
artifact store, whether resume can read a CXDB timeline, and whether an
HTTP-only client in let-go is enough before the binary protocol. It would
also give the shared hub transport, below, a durable event history across
processes.

## Shared hub transport (requested 2026-09-09)

Since 2026-09-09 every CLI command (`run`, `resume`, `agent`, `console`)
submits its work to an in-process hub and renders the hub's event log, so all
commands share one event, question and cancellation contract. The hub has no
network face yet: a CLI cannot attach to a hub owned by another process, and
`serve` is still a separate HTTP server rather than the hub's HTTP view.

Next step: give the hub a socket transport (unix socket, JSON-RPC framing of
the existing request/reply and event-cursor contract, the same shape as the
Codex app-server the codex agent already speaks) and a `--hub <path>` flag so
a CLI attaches instead of embedding. Open decisions: who starts the daemon
and when it exits, how a hub is discovered (`.attractor/hub.sock` under the
repository root is the obvious default), whether `serve` becomes the hub's
HTTP face, and how to authorise clients on a shared machine.

## Self-improving harness (requested 2026-09-08)

The premise: Attractor now drives external agents and its own native loop
from a console over a hub, and the remaining specification work is meant to
be done from inside that console. A self-improving harness closes the loop:
the framework proposes, applies, verifies and records changes to itself under
the same ownership, evidence and publication rules a human session follows.
The user's private notes hold an operating-model essay (shared with them by a
colleague) whose general principles shape this entry; the essay itself is not
in the repository.

Principles carried over from that essay:

- **The unit of delegation is a work package**, not a role: intended outcome,
  relevant sources and revisions, permitted scope, applicable contracts,
  non-goals, acceptance evidence, resource limits and stop conditions.
  "Improve the importer" is not a package; "add interpretation for this
  construct, preserve these semantics, report these unsupported cases,
  demonstrate against these fixtures" is.
- **Separate creating an answer from establishing that it is right.** The
  evaluator starts from the requirement, the contracts and independent
  evidence, not from the implementer's explanation. Two agents agreeing is not
  proof; for the highest-risk work ask what evidence would reveal that both
  are wrong: a historical regression, a reference result approved by a domain
  expert, a consumer-owned acceptance case, an invariant checked over
  generated inputs.
- **Autonomy attaches to a task class and a permission scope**, never to a
  belief that a given agent is trustworthy. Three classes: bounded,
  reversible, non-semantic work with strong checks (eligible for substantial
  automation, including narrowly authorized merge paths); implementation
  within established contracts (agent implementation and verification, human
  review by risk and track record); changes to meaning, compatibility,
  security boundaries or commitments (explicit human decision first).
  Documentation-only does not mean low risk. Widen autonomy on evidence,
  narrow it on failure.
- **Enforce permissions outside the prompt.** Filesystem, network,
  credential and publication rights are technical controls; external
  documents, repository content and imported data are untrusted inputs, not
  sources of authority.
- **Keep an evaluation suite for the workflows themselves**: representative
  past tasks, tricky constraints, expected escalations. Re-run it when
  models, instructions, tools or permissions change; inspect the actual
  cases, since one severe semantic failure outweighs a flattering average.
- **A shared work ledger** where requests become decisions, with response
  distinguished from commitment, work in progress limited by the capacity to
  verify and integrate, and status assembled from evidence rather than
  inferred from merged changes.
- **A periodic cold-start test**: a fresh agent given only the recorded
  materials must find the constraints, the evidence and the uncertainty. That
  tests whether the operating model works without an undocumented human
  dependency.
- **Start with one complete workflow**, then automate its repeated parts,
  rather than building a platform first. Every correction should improve
  something durable: a bug improves the corpus, a review correction improves
  the checks or the recorded guidance.

The design session should settle:

- **Eligible targets and their classes.** Roadmap gaps, review findings,
  failing or flaky evidence, `let-go-followups.md` items and documentation
  drift, each assigned to one of the three autonomy classes above.
- **The loop as a workflow.** Express the cycle as a DOT pipeline the hub runs
  (select target, package, implement through `/agent` or a native session,
  verify, independent review, publish or discard), reusing pinned recovery,
  checkpoints and human gates. Decide what one iteration may change (files,
  worktree, branch) and how parallel iterations are isolated.
- **Verification as the only gate.** Impacted scenarios, the full sentinel
  suite, a bundle outside the checkout, and a review by a different agent
  than the implementer; the behavior corpus and coverage ledger are the source
  of truth, never test counts.
- **Ownership and safety.** Hub ownership with the same cancellation and
  drainage guarantees as any agent job; explicit publication of verified
  checkpoints only; no private notes, no force pushes, no permission
  escalation beyond the user's configuration for that agent; reading
  transcripts, records or model output never evaluates code.
- **Memory.** What an iteration records automatically (iteration log, brain
  notes, follow-ups) so later iterations do not repeat it, and whether the
  harness may edit its own prompts, skills and workflow definitions, and under
  what review class.
- **Budget and stopping.** Bounded spend and wall-clock per iteration,
  discovered model capacity, a user-set stop condition (goal, count, time),
  and a quiet idle state.
- **Evidence.** One autonomous iteration that closes a real roadmap gap end to
  end from the console with its review and publication visible in the hub
  event log; one that correctly discards a change that failed verification;
  and one cold-start run.

### Reference: "The Last Harness You'll Ever Build" (arXiv 2604.21003)

Seong, Yin, Zhang, Shi (Sylph.AI), technical report, v3 dated 2026-05-01.
Read in full on 2026-09-08. It is a framework paper: two algorithms and a
meta-learning correspondence, with no experiments ("we plan to follow up with
empirical results"). What it defines:

- **Harness.** Following "agent = model + harness": every piece of code,
  configuration and execution logic that is not the model. Categories: system
  and task prompts; tools, skills and their descriptions; bundled
  infrastructure (filesystem, sandboxes, browsers, observability); orchestration
  logic (subagents, handoffs, model routing, continuation loops); hooks and
  middleware (compaction, lint checks, verification loops); model
  configuration and routing.
- **Task.** `t = (I, S)`: instructions plus a checklist of verifiable success
  criteria the evaluator judges.
- **Harness Evolution Loop (Algorithm 1).** For `K` iterations: rebuild the
  worker from the previous harness, reset the environment to a clean state,
  execute the task to produce a trace, have the Evaluator produce
  `(report, score)`, record `IMPROVED` or `REGRESSED` against the best score,
  append `(harness, report, score, verdict)` to a history, then have the
  Evolution Agent produce the next harness **from the best one so far** given
  the full history. Return the best harness, its score, and the history.
- **Evaluator `V`.** A separate, adversarial reviewer with four functions:
  state verification (cross-reference the worker's claimed observations with
  ground-truth environment state to catch hallucinated or misread state);
  per-criterion pass/fail; performance auditing (model time versus tool
  time); and two-tier scoring (pass/fail first, execution time as
  tiebreaker), which decides improvement versus regression.
- **Evolution Agent `E`.** Aggregates the history so failed strategies are not
  repeated, classifies failures into recurring patterns (wrong tool usage,
  reasoning loops, misread state, latency), and edits the harness to address
  root causes.
- **Meta-Evolution Loop (Algorithm 2).** The blueprint
  `Λ = (worker, initial harness, V, E)` has the same structure as a harness,
  so a meta agent evolves it across training tasks, judged by mean best score;
  it may change the evaluator prompt, the evolution prompt, what telemetry the
  worker surfaces, what flows between agents, the scoring design, and loop
  hyperparameters (iterations, parallelism, revert thresholds, stopping).
  Generalization is measured on held-out tasks by convergence speed, final
  pass rate, and variance.

What it does and does not protect against: the only guards named are the
evaluator's ground-truth state check and the held-out task set. Because the
meta loop also rewrites the evaluator, the evaluator and evolver can co-adapt;
the paper does not address that, which is exactly the essay's "what evidence
would reveal both agents are wrong" question. Treat its evaluator as
necessary, not sufficient, and keep human-approved reference results and
consumer-owned acceptance cases outside the loop's reach.

How it maps onto Attractor, which already has most of the pieces as data:

| Paper | Attractor |
|---|---|
| Harness components | DOT graphs and `model_stylesheet`, provider profiles and tool registry, execution environment, tool hooks, agent defaults (future user configuration) |
| Task `(I, S)` | A behavior scenario with its corpus command; `S` is the mechanical evidence, never a test count |
| Worker `W_H.execute(t)` → trace | A hub `run` of a DOT pipeline, an `/agent` job, or a native session; the trace is the hub event log plus stage logs |
| Evaluator `V` | An independent review through `bin/attractor agent` with a different agent than the implementer, plus the corpus as ground truth; state verification is the project's existing rule to witness cleanup mechanically rather than trust flags |
| History | Iteration log, hub event log, brain notes |
| Evolution `E` | An `/agent` job whose permitted scope is the harness data above, never the corpus or reference results |
| Loop | A DOT pipeline with pinned recovery, run by the hub, with human gates at the autonomy-class boundaries |
| Meta loop / `Λ` | The iteration skills, review checklists and this design; evolving them is class three (human decision) until evidence says otherwise |

Tool building is in scope for the paper's evolver: tools, skills and their
descriptions are a harness category, and the evolution agent may edit "tool
implementations" like any other component, judged only by the next score.
The paper says nothing about how a new tool is specified, tested or bounded.
For Attractor, tool changes are where capability widens, so they sit one
autonomy class above prompt or orchestration edits: rewording or tightening
an existing registry tool is class two (agent implements, independent
review); adding a tool that grants new filesystem, shell or network reach is
class three (human decision), because permissions are enforced outside the
prompt and the evolver must not widen them by editing code.

Design questions this adds to the list above: which harness components an
iteration may edit per autonomy class; where the clean-state reset boundary
is (worktree, logs root, hub state); how a two-tier score is derived from the
corpus and ledger; what "evolve from the best harness" means when the best is
a published checkpoint; and how held-out scenarios are kept from the evolver.

Follow-ups noted with the request: consider converting the operating-model
essay into this project's natural-language spec form or an RFC so its rules
become checkable, and read the other reference it cites, a case study on a
long-running agent harness for multi-context software development.

Depends on user configuration (above) for budgets, agent defaults and
publication targets, and on executable packets (below) if iterations are to
be shared or replayed.

## Executable packets and skill packages (requested 2026-09-06)

Recorded in `superpowers/iterations/roadmap.md` under "Future design:
executable packets and skill packages"; the design questions live there. PEG
improvements are a separate owner's workstream and are not part of this.

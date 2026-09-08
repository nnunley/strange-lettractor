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

Follow-ups noted with the request: consider converting the operating-model
essay into this project's natural-language spec form or an RFC so its rules
become checkable, and read the two references it cites, a case study on a
long-running agent harness for multi-context software development and
arXiv 2604.21003, before the design session.

Depends on user configuration (above) for budgets, agent defaults and
publication targets, and on executable packets (below) if iterations are to
be shared or replayed.

## Executable packets and skill packages (requested 2026-09-06)

Recorded in `superpowers/iterations/roadmap.md` under "Future design:
executable packets and skill packages"; the design questions live there. PEG
improvements are a separate owner's workstream and are not part of this.

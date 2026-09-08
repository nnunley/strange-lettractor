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

The user keeps a private note on a self-improving harness; this public entry
records the request and the questions to settle, not the note's content. The
premise: Attractor now drives external agents and its own native loop from a
console over a hub, and the remaining specification work is meant to be done
from inside that console. A self-improving harness closes the loop: the
framework proposes, applies, verifies and records changes to itself under the
same ownership, evidence and publication rules a human session follows.

The design session should settle:

- **What "improve" means.** Candidate targets: conformance gaps in the
  iteration roadmap, review findings, failing or flaky evidence, runtime
  follow-ups in `let-go-followups.md`, and documentation drift. Decide which
  are eligible for autonomous work and which stay human-directed.
- **The loop as a workflow.** Express the cycle as a DOT pipeline the hub runs
  (select target, plan, implement through `/agent` or a native session,
  verify, review, publish or discard), so it uses pinned recovery,
  checkpoints and human gates rather than a bespoke scheduler. Decide what a
  single iteration is allowed to change (files, worktree, branch) and how
  parallel iterations are isolated.
- **Verification as the gate.** An iteration succeeds only on mechanical
  evidence: the impacted scenarios, the full sentinel suite, a bundle outside
  the checkout, and an independent review through a different agent than the
  implementer. No claim of completion from test counts alone; the existing
  behavior corpus and coverage ledger are the source of truth.
- **Ownership and safety.** The harness runs under hub ownership with the
  same cancellation and drainage guarantees as any agent job. Publication
  stays explicit: verified checkpoints to `main`/`console`, never private
  notes, never force pushes, and no permission escalation beyond what the
  user configured for that agent. Reading transcripts, records or model output
  never evaluates code.
- **Memory and learning.** How an iteration records what it tried, what
  failed and why, so later iterations do not repeat it: the iteration log,
  brain notes, and let-go follow-ups already exist; decide what is written
  automatically and in what form. Decide whether the harness may edit its own
  prompts, skills and workflow definitions, and under what review.
- **Budget and stopping.** Bounded model spend and wall-clock per iteration,
  discovered model capacity rather than assumed, a stop condition the user
  sets (goal, count, time), and an idle/quiet state that does not burn tokens.
- **Evidence.** One autonomous iteration that closes a real roadmap gap end to
  end from the console, with its review and publication visible in the hub
  event log, and one that correctly discards a change that failed
  verification.

Depends on user configuration (above) for budgets, agent defaults and
publication targets, and on executable packets (below) if iterations are to
be shared or replayed.

## Executable packets and skill packages (requested 2026-09-06)

Recorded in `superpowers/iterations/roadmap.md` under "Future design:
executable packets and skill packages"; the design questions live there. PEG
improvements are a separate owner's workstream and are not part of this.

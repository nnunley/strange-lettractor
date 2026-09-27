# Strange Lettractor

Strange Lettractor is a unified agentic framework for building provider-independent LLM applications, tool-using agents, and composable workflows in [let-go](https://github.com/nooga/let-go). It implements [StrongDM's Attractor specifications](https://github.com/strongdm/attractor) across three complementary layers:

- [Unified LLM client](specs/unified-llm-spec.md): a common interface across OpenAI, Anthropic, and Google Gemini for multimodal generation, first-class streaming, structured output, and tool calling, using native provider APIs and explicit access to provider-specific capabilities.
- [Coding agent runtime](specs/coding-agent-loop-spec.md): stateful agent sessions that combine model calls, tools, and execution environments.
- [Workflow orchestration](specs/attractor-spec.md): composable Graphviz DOT pipelines with branching, parallel execution, human interaction, and checkpoint recovery.

Applications can use the LLM client and agent runtime directly, without a DOT workflow. Workflow orchestration builds on those foundations; it does not define the framework's entire scope.

## Conformance to the upstream README

The upstream [README](https://github.com/strongdm/attractor) asks for an
implementation of its three NLSpecs and recommends bringing your own agentic
loop and unified LLM SDK rather than wrapping a vendor's. Strange Lettractor
does both, in let-go:

| Upstream README item | Where it lives here | Evidence |
|---|---|---|
| Attractor Specification | `src/attractor/{parser,engine,handlers,server,...}.lg` | [Runtime requirements and evidence](docs/superpowers/iterations/requirements/attractor.md) |
| Coding Agent Loop Specification | `src/attractor/{agent,profiles,execution,subagent}.lg` (own loop, no external agent SDK) | [Component, native-wire, and live evidence](docs/superpowers/iterations/requirements/coding-agent-loop.md) |
| Unified LLM Client Specification | `src/attractor/llm.lg` (own SDK: native OpenAI, Anthropic, Gemini adapters plus `openai-compat`) | [Component checks and remaining provider gaps](docs/superpowers/iterations/requirements/unified-llm.md) |
| "Build your own software factory" | `bin/attractor run`, `console`, `agent`, `serve` | [tutorial](docs/tutorial.md), [behavior corpus](docs/superpowers/iterations/behavior-corpus.md) |

The ledgers and audits distinguish tested behavior from remaining requirements;
the full suite is `lgx suite` (`make test`). Schema validation passes the mandatory
2020-12 corpus under its [documented support contract](docs/schema-validation.md).
Native-provider live coverage and complete parity/smoke evidence remain incomplete.
See the [current specification audit](docs/superpowers/iterations/spec-closure.md)
for verified results and remaining gaps. Historical story counts alone do not
establish full specification conformance.

It is built with [lgx](https://github.com/abogoyavlensky/lgx) and runs on a
stock [let-go](https://github.com/nooga/let-go) release.

## Build and run

Generated test reports and live-run artifacts stay in ignored `evidence/`, outside
the documentation tree. See [verification output](docs/verification.md) for the
test commands and retention policy.

Prerequisites:

- [let-go](https://github.com/nooga/let-go) 1.13.0 on `PATH` as `lg`. That
  release carries everything Attractor needs, including the native TCP listener
  and correct JSON object keys that this project previously had to patch in
  locally. `lgx.edn` pins the version; lgx refuses to run on a mismatch.
- [lgx](https://github.com/abogoyavlensky/lgx) 0.3.2 or newer.
- Optional external agents on `PATH`: [Claude Code](https://code.claude.com)
  (`claude`) and [Codex](https://github.com/openai/codex) (`codex`). Optional: a
  OpenAI-compatible Chat Completions endpoint (llama.cpp, Ollama, vLLM) for
  live models, addressed as `openai-compat/<model>`.

Provider keys and live-runner options come from `.env` in the working
directory; `.env.sample` lists every variable the code reads. Set `LGX_LG` only
to override the runtime with a local let-go build.

Every entry point is an lgx task; `lgx help` lists them, and the Makefile is a
thin passthrough over the same tasks.

```sh
# Layout: src/ code; test/attractor/ suites; test/fixtures/ loopback servers;
# test/live/ credential-gated gates; test/probes/ manual checks and let-go
# issue reproducers; lgx test discovers the full suite.
lgx install            # fetches tiny-tui (pinned in lgx.edn)
lgx rebuild            # bin/attractor      (make build)
lgx test               # full suite (lgx suite / make test are aliases)
lgx audit-coding-loop  # original coding-loop contracts and repair regressions
lgx live-coding-conformance  # native-provider parity + same-session smoke; uses credentials
lgx test-ns attractor.validation-test   # one namespace   (make run-validation)
lgx runners            # each namespace in its own process (make runners)
bin/attractor help
```

The [coding-loop audit](docs/coding-loop-audit-2026-09-27.md) maps original
requirements to evidence and records four repaired implementation defects. Its
named suite passes 233 tests / 2380 assertions; the repairs are also covered by
regular tests. Full live-provider parity and shared-session smoke remain open.

lgx 0.3.2 includes the `clojure.test` runner fix for let-go 1.13.0.
`lgx suite` and `make test` delegate to its built-in `lgx test` command.
The local `test/runner.lg` remains available for namespace selection, deadline
diagnostics, and the per-namespace summary format used by `lgx runners`.

Rebuild after every pull: `bin/attractor` is a build artifact, not tracked.

### Console

The console is the interactive front door: conversation with the native
agent, let-go evaluation, workflow runs and external agent jobs in one place,
over a local hub or an attached nREPL hub. Two things are named everywhere: a **model**, addressed
as `provider/name`, and an **agent**, anything that runs a tool loop against a
model (`native` is Attractor's own; `claude` and `codex` are external).

```sh
bin/attractor console --mock          # line console, mock model
bin/attractor console --tui --mock    # full-screen tiny-tui console
bin/attractor console --connect 4555  # attach to an existing loopback nREPL hub

# live model through an OpenAI-compatible endpoint (llama.cpp shown)
OPENAI_COMPAT_BASE_URL=http://localhost:8080/v1 OPENAI_COMPAT_API_KEY=local \
  bin/attractor console --tui --model qwen3.8-27b --provider openai-compat
```

For a persistent hub, run `bin/attractor hub --mock --port 4555` in one terminal
and attach with `console --connect 4555` in another. Quitting a client preserves
hub work; `bin/attractor hub --stop 4555` shuts down the host. See
[hub usage](docs/hub.md) for ownership, attachment and HTTP access.

Inside the console:

| Input | Effect |
|---|---|
| `text` | message the native agent session |
| `: (form)` | evaluate let-go in the hub namespace (`hub`, `request!`, `*session*`, `*run*` are bound) |
| `:{` … `:}` | multiline evaluation |
| `\text` | literal agent text |
| `/run file.dot --auto-approve` | launch a workflow and stream its events |
| `/agent claude\|codex <prompt> [--cwd d] [--model m] [--tools a,b] [--permission-mode p] [--sandbox s] [--approval-policy p]` | start an external agent job |
| `/alias codex agent codex` | define an explicit shortcut (`/codex …`); none exist by default. `--alias name=expansion` at startup does the same |
| `/list`, `/focus <id>`, `/new`, `/cancel`, `/quit` | list sessions/runs/jobs, select, open a session, cancel, leave |
| `/answer <key or text>` | answer a pending human gate, preferring the focused workflow |

In the TUI, Ctrl-C discards a multiline draft, cancels busy focused work, or
quits when idle. Human-gated workflows can be answered with `/answer`;
`--auto-approve` selects an answer automatically. See
[console requirements and evidence](docs/_archive/console-requirements.md).

### Pipelines

```sh
bin/attractor validate examples/hello.dot
bin/attractor run examples/hello.dot --auto-approve      # mock model unless keys/--llm
bin/attractor run examples/hello.dot --agent claude      # an external agent as the codergen backend
bin/attractor run examples/hello.dot --agent codex --sandbox workspace-write
lgx run-pipeline examples/hello.dot                      # the same through lgx
```

See the [tutorial](docs/tutorial.md) for pipeline examples, configuration, and CLI usage.
For local-model development with verification, human review and frontier escalation,
use the [development REPL workflow](docs/development-repl.md).
For an imported attempt/verify/critique loop, see the
[adapted Amplifier task runner](examples/task-runner/README.md).
For controller checks implemented as bound let-go functions, see
[embedded paired review](docs/embedded-review.md).
See [deployment context discovery](docs/context-capacity.md) for live capacity,
explicit overrides, advisory fallback, and the current local-runtime prerequisite.

## Providers

Providers live in a registry: an id, the wire protocol it speaks
(`:openai-responses`, `:anthropic-messages`, `:gemini-generate-content` or
`:openai-chat-completions`), its base URL, the environment variable holding
its key, and whether `/models` may be queried. `openai`, `anthropic`,
`gemini` and `openai-compat` are built in; add or override entries in
`./attractor.edn` (see `attractor.edn.sample`) or
`~/.config/attractor/attractor.edn`. Files are data only; an entry holds its
key or bearer token in `:api_key` (the file must then be `chmod 600`), names
the environment variable in `:api_key_env`, or borrows another entry's key
with `:api_key_from`. `:auth` chooses how the key is sent (`:bearer`,
`:optional-bearer`, `:header` with `:auth_header`, or `:none`), and
`:credential_headers` always win over the derived header. Evidence and live
runner output pass through a redactor that replaces every configured
credential with `<credential>`. Any configured id can be
used as a model prefix (`openrouter/<model>`) and with `models --provider <id>`.

```sh
bin/attractor providers          # effective registry with each value's source
bin/attractor models --provider openrouter
```

## One control plane: the hub

Every command that does work (`run`, `resume`, `agent`, `console`) submits it
to a hub (`src/attractor/hub.lg`) and renders the hub's event log. Human
gates are hub questions: the console answers them with `/answer`, while `run`
and `resume` answer them on the process's stdin and hand the answer back to
the hub. Tools still execute locally inside the session that owns them; the
hub owns submission, events, questions and cancellation. `run`, `resume`,
`agent`, and an unattached `console` embed a hub. `hub` runs a persistent
loopback nREPL host; `console --connect PORT` attaches without creating another
hub. `serve --connect PORT` exposes that same hub through HTTP, while `serve`
without `--connect` owns a hub and an nREPL listener. Client detach preserves
host-owned work. See [hub usage and current limits](docs/hub.md).

## External agents

An agent is anything that runs its own tool loop against a model. Attractor's
native loop is one; Claude Code and Codex are external agents wrapped as
streaming connectors. Agents are named explicitly; nothing is assumed when the
name is absent.

```sh
bin/attractor agent claude --prompt-file examples/claude-smoke.md --cwd .
bin/attractor agent codex  --prompt-file examples/claude-smoke.md --cwd . --sandbox read-only
```

Both stream identified EDN events and default to read-only access. DOT runs
select an agent with `--agent <name>`; the console with `/agent <name>`. See
[Claude Code agent](docs/_archive/claude-agent.md) and
[Codex app-server agent](docs/_archive/codex-app-server.md).

## Workflow lifecycle

Use `attractor.pipeline/prepare` to parse, transform, and validate DOT source
without execution. Use `attractor.pipeline/run` for the same preparation plus
validation-gated execution. `attractor.engine/run-pipeline` is the low-level API
for callers that already hold a parsed, transformed, and validated graph.

Public runs save an immutable workflow capture alongside `checkpoint.edn`.
`attractor.pipeline/execute-prepared` publishes and runs an existing preparation;
`attractor.pipeline/resume` takes a checkpoint path and resumes the captured plan,
even if the original DOT file has changed or disappeared. Source changes produce
drift warnings; missing or corrupt captures stop recovery before execution.
Loop restarts retain independently resumable captures in their fresh run directories.

[Tool-call hooks](docs/_archive/tool-hooks.md) provide pre-call checks and post-call auditing,
with graph/node configuration and EDN stage logs.

## License

[Apache License 2.0](LICENSE)

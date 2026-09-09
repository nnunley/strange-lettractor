# Strange Lettractor

Strange Lettractor is a unified agentic framework for building provider-independent LLM applications, tool-using agents, and composable workflows in [let-go](https://github.com/nooga/let-go). It implements [StrongDM's Attractor specifications](https://github.com/strongdm/attractor) across three complementary layers:

- [Unified LLM client](docs/upstream/strongdm-attractor/unified-llm-spec.md): a common interface across OpenAI, Anthropic, and Google Gemini for multimodal generation, first-class streaming, structured output, and tool calling, using native provider APIs and explicit access to provider-specific capabilities.
- [Coding agent runtime](docs/upstream/strongdm-attractor/coding-agent-loop-spec.md): stateful agent sessions that combine model calls, tools, and execution environments.
- [Workflow orchestration](docs/upstream/strongdm-attractor/attractor-spec.md): composable Graphviz DOT pipelines with branching, parallel execution, human interaction, and checkpoint recovery.

Applications can use the LLM client and agent runtime directly, without a DOT workflow. Workflow orchestration builds on those foundations; it does not define the framework's entire scope.

## Conformance to the upstream README

The upstream [README](docs/upstream/strongdm-attractor/README.md) asks for an
implementation of its three NLSpecs and recommends bringing your own agentic
loop and unified LLM SDK rather than wrapping a vendor's. Strange Lettractor
does both, in let-go:

| Upstream README item | Where it lives here | Evidence |
|---|---|---|
| Attractor Specification | `src/attractor/{parser,engine,handlers,server,...}.lg` | all 33 stories done or proved: [ledger](docs/superpowers/iterations/requirements/attractor.md) |
| Coding Agent Loop Specification | `src/attractor/{agent,profiles,execution,subagent}.lg` (own loop, no external agent SDK) | 8 of 13 stories done at component level, 5 partial with named residuals: [ledger](docs/superpowers/iterations/requirements/coding-agent-loop.md) |
| Unified LLM Client Specification | `src/attractor/llm.lg` (own SDK: native OpenAI, Anthropic, Gemini adapters plus `openai-compat`) | 10 of 12 stories done at component level; release gate credential-gated: [ledger](docs/superpowers/iterations/requirements/unified-llm.md) |
| "Build your own software factory" | `bin/attractor run`, `console`, `agent`, `serve` | [tutorial](docs/tutorial.md), [behavior corpus](docs/superpowers/iterations/behavior-corpus.md) |

Every claim in the ledgers is backed by a runnable check in the behavior
corpus; the full suite is `lgx test`. What is not closed is stated in the
ledgers rather than implied: live OpenAI/Anthropic/Gemini parity needs real
API keys for `dev/provider_matrix_live.lg`, and the partial coding-loop rows
list their residuals. Full specification conformance is therefore claimed at
component level, not as a live release.

It is built with [lgx](https://github.com/abogoyavlensky/lgx) and requires let-go 1.12.2 or newer.

## Build and run

Prerequisites:

- [lgx](https://github.com/abogoyavlensky/lgx) 0.1.0-rc2 or newer.
- A let-go 1.12.2+ executable with local runtime fixes that upstream has not
  released yet (nooga/let-go [#816](https://github.com/nooga/let-go/issues/816),
  [#830](https://github.com/nooga/let-go/issues/830), [#831](https://github.com/nooga/let-go/issues/831),
  [#832](https://github.com/nooga/let-go/issues/832), [#833](https://github.com/nooga/let-go/issues/833)).
  Build it from the `fix/http-scope-cancellation` bookmark of the local let-go
  workspace with `go build -o build/lg .` and point `LGX_LG` at the result. A
  stock release runs most of the suite, but the console's evaluation capture
  and held-stream cancellation depend on those fixes; see
  [let-go follow-ups](docs/let-go-followups.md).
- Optional external agents on `PATH`: [Claude Code](https://code.claude.com)
  (`claude`) and [Codex](https://github.com/openai/codex) (`codex`). Optional: a
  OpenAI-compatible Chat Completions endpoint (llama.cpp, Ollama, vLLM) for
  live models, addressed as `openai-compat/<model>`.

Provider keys and live-runner options come from `.env` in the working
directory; `.env.sample` lists every variable the code reads. Every command
below reads the runtime from `LGX_LG`; the `lg` on your `PATH` may be older,
so always set it:

```sh
export LGX_LG=/path/to/let-go/build/lg   # the fixed local build
lgx install                              # fetches tiny-tui (pinned in lgx.edn)
lgx build                                # bin/attractor
lgx test                                 # full suite (~2 min)
bin/attractor help
```

Rebuild after every pull: `bin/attractor` is a build artifact, not tracked.

### Console

The console is the interactive front door: conversation with the native
agent, let-go evaluation, workflow runs and external agent jobs in one place,
over an in-process hub. Two things are named everywhere: a **model**, addressed
as `provider/name`, and an **agent**, anything that runs a tool loop against a
model (`native` is Attractor's own; `claude` and `codex` are external).

```sh
bin/attractor console --mock          # line console, mock model
bin/attractor console --tui --mock    # full-screen tiny-tui console

# live model through an OpenAI-compatible endpoint (llama.cpp shown)
OPENAI_COMPAT_BASE_URL=http://localhost:8080/v1 OPENAI_COMPAT_API_KEY=local \
  bin/attractor console --tui --model qwen3.8-27b --provider openai-compat
```

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

In the TUI, Ctrl-C discards a multiline draft, cancels busy focused work, or
quits when idle. Human-gated workflows need `--auto-approve` for now. See
[console requirements and evidence](docs/console-requirements.md).

### Pipelines

```sh
bin/attractor validate examples/hello.dot
bin/attractor run examples/hello.dot --auto-approve      # mock model unless keys/--llm
bin/attractor run examples/hello.dot --agent claude      # an external agent as the codergen backend
bin/attractor run examples/hello.dot --agent codex --sandbox workspace-write
lgx run-pipeline examples/hello.dot                      # the same through lgx
```

See the [tutorial](docs/tutorial.md) for pipeline examples, configuration, and CLI usage.
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
key or bearer token in `:api_key` (the file must then be `chmod 600`) or
names the environment variable in `:api_key_env`. Any configured id can be
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
hub only owns submission, events, questions and cancellation. Today each CLI
process embeds its own hub. Attaching to a running hub over a socket is
recorded in [future work](docs/future_work.md).

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
[Claude Code agent](docs/claude-agent.md) and
[Codex app-server agent](docs/codex-app-server.md).

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

[Tool-call hooks](docs/tool-hooks.md) provide pre-call checks and post-call auditing,
with graph/node configuration and EDN stage logs.

## License

[Apache License 2.0](LICENSE)

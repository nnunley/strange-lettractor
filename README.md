# Strange Lettractor

Strange Lettractor is a unified agentic framework for building provider-independent LLM applications, tool-using agents, and composable workflows in [let-go](https://github.com/nooga/let-go). It implements [StrongDM's Attractor specifications](https://github.com/strongdm/attractor) across three complementary layers:

- [Unified LLM client](docs/upstream/strongdm-attractor/unified-llm-spec.md): a common interface across OpenAI, Anthropic, and Google Gemini for multimodal generation, first-class streaming, structured output, and tool calling, using native provider APIs and explicit access to provider-specific capabilities.
- [Coding agent runtime](docs/upstream/strongdm-attractor/coding-agent-loop-spec.md): stateful agent sessions that combine model calls, tools, and execution environments.
- [Workflow orchestration](docs/upstream/strongdm-attractor/attractor-spec.md): composable Graphviz DOT pipelines with branching, parallel execution, human interaction, and checkpoint recovery.

Applications can use the LLM client and agent runtime directly, without a DOT workflow. Workflow orchestration builds on those foundations; it does not define the framework's entire scope. Implementation is in progress; full specification conformance is not yet claimed.

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
- Optional agentic frameworks on `PATH`: [Claude Code](https://code.claude.com)
  (`claude`) and [Codex](https://github.com/openai/codex) (`codex`, app-server
  protocol). Optional: a llama.cpp or Ollama-compatible endpoint for live models.

Every command below reads the runtime from `LGX_LG`; the `lg` on your `PATH`
may be older, so always set it:

```sh
export LGX_LG=/path/to/let-go/build/lg   # the fixed local build
lgx install                              # fetches tiny-tui (pinned in lgx.edn)
lgx build                                # bin/attractor
lgx test                                 # full suite (~2 min)
bin/attractor help
```

Rebuild after every pull: `bin/attractor` is a build artifact, not tracked.

### Console

The console is the interactive front door: agent conversation, let-go
evaluation, workflow runs and external workers in one place, over an
in-process hub.

```sh
bin/attractor console --mock          # line console, mock model
bin/attractor console --tui --mock    # full-screen tiny-tui console

# live model through an OpenAI-compatible endpoint (llama.cpp shown)
OLLAMA_BASE_URL=http://localhost:8080/v1 OLLAMA_API_KEY=local \
  bin/attractor console --tui --model qwen3.8-27b --provider ollama
```

Inside the console:

| Input | Effect |
|---|---|
| `text` | message the focused agent session |
| `: (form)` | evaluate let-go in the hub namespace (`hub`, `request!`, `*session*`, `*run*` are bound) |
| `:{` … `:}` | multiline evaluation |
| `\text` | literal agent text |
| `/run file.dot --auto-approve` | launch a workflow and stream its events |
| `/agent --framework claude\|codex <prompt> [--cwd d] [--model m] [--tools a,b] [--permission-mode p] [--sandbox s] [--approval-policy p]` | dispatch an owned agentic-framework worker |
| `/alias claude agent --framework claude` | define an explicit shortcut (`/claude …`); none exist by default. `--alias name=expansion` at startup does the same |
| `/agents`, `/focus <id>`, `/new`, `/cancel`, `/quit` | list, select, open, cancel, leave |

In the TUI, Ctrl-C discards a multiline draft, cancels busy focused work, or
quits when idle. Human-gated workflows need `--auto-approve` for now. See
[console requirements and evidence](docs/console-requirements.md).

### Pipelines

```sh
bin/attractor validate examples/hello.dot
bin/attractor run examples/hello.dot --auto-approve      # mock model unless keys/--llm
bin/attractor run examples/hello.dot --worker claude     # an agentic framework as the codergen worker
bin/attractor run examples/hello.dot --worker codex --sandbox workspace-write
lgx run-pipeline examples/hello.dot                      # the same through lgx
```

See the [tutorial](docs/tutorial.md) for pipeline examples, configuration, and CLI usage.
See [deployment context discovery](docs/context-capacity.md) for live capacity,
explicit overrides, advisory fallback, and the current local-runtime prerequisite.

## Agentic framework workers

Three things are configured separately: the **provider** (the network model
client: OpenAI, Anthropic, Gemini, Ollama, llama.cpp), the **model** name, and
the **agentic framework** (a streaming wrapper around an external coding agent
that runs its own tool loop). Frameworks are selected explicitly with
`--framework`; nothing is assumed when it is absent.

```sh
bin/attractor agent --framework claude --prompt-file examples/claude-smoke.md --cwd .
bin/attractor agent --framework codex  --prompt-file examples/claude-smoke.md --cwd . --sandbox read-only
```

Both stream identified EDN events and default to read-only access. DOT runs
select a framework with `--worker <framework>`; the console with
`/agent --framework <framework>`. See [Claude Code worker](docs/claude-worker.md)
and [Codex app-server worker](docs/codex-app-server.md).

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

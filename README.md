# Strange Lettractor

Strange Lettractor is a unified agentic framework for building provider-independent LLM applications, tool-using agents, and composable workflows in [let-go](https://github.com/nooga/let-go). It implements [StrongDM's Attractor specifications](https://github.com/strongdm/attractor) across three complementary layers:

- [Unified LLM client](docs/upstream/strongdm-attractor/unified-llm-spec.md): a common interface across OpenAI, Anthropic, and Google Gemini for multimodal generation, first-class streaming, structured output, and tool calling, using native provider APIs and explicit access to provider-specific capabilities.
- [Coding agent runtime](docs/upstream/strongdm-attractor/coding-agent-loop-spec.md): stateful agent sessions that combine model calls, tools, and execution environments.
- [Workflow orchestration](docs/upstream/strongdm-attractor/attractor-spec.md): composable Graphviz DOT pipelines with branching, parallel execution, human interaction, and checkpoint recovery.

Applications can use the LLM client and agent runtime directly, without a DOT workflow. Workflow orchestration builds on those foundations; it does not define the framework's entire scope. Implementation is in progress; full specification conformance is not yet claimed.

It is built with [lgx](https://github.com/abogoyavlensky/lgx) and requires let-go 1.12.2 or newer.

## Quick start

```sh
export LGX_LG="$HOME/development/let-go/lg"
lgx test
lgx build
lgx run-pipeline examples/hello.dot
```

See the [tutorial](docs/tutorial.md) for pipeline examples, configuration, and CLI usage.

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

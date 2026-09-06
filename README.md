# Strange Lettractor

Strange Lettractor is a unified agentic framework implementing [StrongDM's Attractor specifications](https://github.com/strongdm/attractor). Its scope spans three complementary layers:

- [Unified LLM client](docs/upstream/strongdm-attractor/unified-llm-spec.md): a common interface across model providers for generation, streaming, structured output, and tool calling, while retaining provider-specific capabilities.
- [Coding agent runtime](docs/upstream/strongdm-attractor/coding-agent-loop-spec.md): stateful agent sessions that combine model calls, tools, and execution environments.
- [Workflow orchestration](docs/upstream/strongdm-attractor/attractor-spec.md): composable Graphviz DOT pipelines with branching, parallel execution, human interaction, and checkpoint recovery.

The LLM and agent layers are foundations for applications in their own right; DOT workflows are one way to compose them. Implementation is in progress; full specification conformance is not yet claimed.

It is written in [let-go](https://github.com/nooga/let-go) and built with [lgx](https://github.com/abogoyavlensky/lgx). It requires let-go 1.12.2 or newer.

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

## License

[Apache License 2.0](LICENSE)

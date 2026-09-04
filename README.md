# Strange Lettractor

Strange Lettractor is an implementation of [StrongDM's Attractor](https://github.com/strongdm/attractor), a specification for orchestrating multi-stage LLM workflows as Graphviz DOT pipelines.

It is written in [let-go](https://github.com/nooga/let-go) and built with [lgx](https://github.com/abogoyavlensky/lgx). It requires let-go 1.12.2 or newer.

## Quick start

```sh
export LGX_LG="$HOME/development/let-go/lg"
lgx test
lgx build
lgx run-pipeline examples/hello.dot
```

See the [tutorial](docs/tutorial.md) for pipeline examples, configuration, and CLI usage.

## Programmatic lifecycle

Use `attractor.pipeline/prepare` to parse, transform, and validate DOT source
without execution. Use `attractor.pipeline/run` for the same preparation plus
validation-gated execution. `attractor.engine/run-pipeline` is the low-level API
for callers that already hold a parsed, transformed, and validated graph.

## License

[Apache License 2.0](LICENSE)

# Current catalog refresh — 2026-09-23

Original scope: unified-LLM §§2.9 and 8.1. Read-only official-source audit by
gpt-6-luna found one incorrect limit and several missing current general-purpose
entries. Implement this bounded refresh after the current schema integration,
using gpt-6-luna. Keep the catalog advisory and preserve explicit model strings.

| Entry | Verified change | Source |
|---|---|---|
| `claude-opus-4-6` | Correct context from 200,000 to 1,000,000; output remains 128,000 | [Official model page](https://platform.claude.com/docs/en/models/opus-4-6/overview) |
| `claude-opus-5-5` | Add 1,000,000 context, 128,000 output, reliable cutoff 2026-06; adaptive thinking is always on and forced tool choice is unsupported | [Official model page](https://platform.claude.com/docs/en/models/opus-5-5/overview) |
| `gpt-6-sol` | Add 1,050,000 context, 128,000 output, reliable cutoff 2026-04-20 | [Official model page](https://developers.openai.com/api/docs/models/gpt-6-sol) |
| `gpt-6-luna` | Add 1,050,000 context, 128,000 output, reliable cutoff 2026-05-18 | [Official model page](https://developers.openai.com/api/docs/models/gpt-6-luna) |
| `claude-sonnet-4-5` | Add newly verified reliable cutoff 2025-01; current 200,000/64,000 limits are correct | [Official model page](https://platform.claude.com/docs/en/models/sonnet-4-5/overview) |

All three added current models support tool calls, image input and reasoning.
Verify the exact current metadata against these primary sources at implementation
time and record the source links with cutoff fields. Retain existing aliases,
and add new IDs without silently repointing old aliases.

The audit suggested making Opus 5.5 the default because Anthropic recommends
it for most workloads. Keep the existing quality-oriented Fable-first order:
the spec's lookup permits newest/best selection, and the official lineup still
identifies Fable for the most demanding work. Insert Opus 5.5 ahead of Opus 5;
insert Sol and Luna after Astra and before older OpenAI entries. Changing an
application's cost/quality preference is not necessary for factual freshness.
[Anthropic lineup](https://platform.claude.com/docs/en/models/overview).

Use the existing model capability metadata for Opus 5.5
(`:reasoning_mode :adaptive`, `:adaptive_only true`,
`:forced_tool_choice false`). Verify completion and streaming request behavior
through the shared Anthropic adapter, including rejection before transport of
unsupported forced choice or disabled thinking. Run impacted catalog/default
selection, prompt metadata and context-capacity checks. New assertions should
prove request/selection behavior rather than merely copy the data table.

The audit found current Gemini entries and retained older IDs still documented;
do not remove them. A selective catalog need not enumerate every served model:
Sonnet 4.6 and additional older Gemini generations remain optional additions.
Do not introduce network-dependent catalog/auth configuration; the existing
project decision in `docs/future_work.md` rejects that approach. Append dated
evidence to `docs/provider-model-audits.md`; preserve its historical refreshes.
Catalog metadata and deterministic adapter tests do not prove live account access.

Existing focused namespaces: `attractor.anthropic-modern-model-contract-test`,
`attractor.llm-test`, `attractor.llm-contract-test`,
`attractor.default-model-contract-test`, `attractor.prompt-metadata-test` and
`attractor.context-capacity-test`. The existing Anthropic request-capture helper
calls the real completion/streaming serializers through a supplied transport;
extend it for the new capability entry instead of introducing another adapter.

## Completed checkpoint — ITER-0019, 2026-09-23

Implemented by gpt-6-luna. Fresh root verification passes 137 tests / 822
assertions / zero failures/errors across the six namespaces above; log
`/tmp/attractor-catalog-focused-20260923.log`. Paired independent spec and
quality reviewers approve. Quality reviewers independently pass the three
changed namespaces (16 tests / 169 assertions). Fresh standalone CLI
`/tmp/attractor-catalog-cli-20260923` validates `examples/hello.dot`
(5 nodes / 4 edges, no diagnostics). Final `lgx test` on lgx 0.3.2 passes
**1485 tests / 13406 assertions / zero failures**, exit 0; log
`/tmp/attractor-catalog-integrated-20260923.log`. No commit or publication was
made, and native-provider cells remain unproved.

Review confirmed a pre-existing final-audit item in unified-LLM §2.9: the
catalog should be a separately updateable offline data artifact. This bounded
metadata/capability patch does not change its source-namespace packaging. Do
not conflate that packaging choice with network-dependent provider/auth config,
which remains excluded by the existing project decision.

Packaging research for that later audit: the current
[lgx manifest documentation](https://github.com/abogoyavlensky/lgx#paths-main-resource-paths)
supports `:resource-paths` for run/test and embedding during build, but resource
roots are project-owned and are not inherited from dependencies. let-go's
`io/resource` documentation also makes bundled resources filesystem-independent.
An eventual offline data extraction must preserve source-library loading and
standalone binaries, including direct `lg` and subprocess test entry points;
adding a repository-relative runtime read alone would break those contracts.
This records available mechanisms and constraints, not a selected implementation.

A bounded gpt-6-luna probe subsequently verified another available mechanism:
let-go binds `*file*` while loading a dependency namespace, so an internal macro
can derive a sibling EDN path, read it with `edn/read-string` and emit quoted
constant data. In `/tmp/lg-edn-probe.96RjVJ`, a two-record mini-catalog loaded
through an explicit dependency source path from another working directory.
`lg -b` embedded the value; the binary still returned the same records from `/`
after its original source tree was moved away. Removing EDN made raw source
loading fail during macro expansion with the missing path. No generator or
resource flags were needed. Root independently reran source loading from `/tmp`
using the relocated source path and the standalone binary from `/`; both exited
0 with identical data. Ordinary maps/vectors/keywords/strings/booleans were
probed. This is mechanism evidence, not a selected project implementation.
Source consumers would need the colocated data file at load time; bundled
binaries would need a rebuild to incorporate updated data.

The subsequent [offline catalog implementation plan](../plans/2026-09-23-offline-model-catalog.md)
has passed independent plan review. It uses complete-input EDN reading and
proves data-only changes through the real public namespace before checking a
source-removed standalone binary. Implementation remains queued; the catalog
still resides in `models.lg` until that task is executed and verified.

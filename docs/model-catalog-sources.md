# Model catalog sources

`src/attractor/models.lg` records a `:knowledge_cutoff` only where the vendor
publishes one. Values are the vendor's *reliable* cutoff where two dates are
given. Anything not listed here is reported as `unknown` in the system
prompt's environment context. Verified 2026-09-10.

| Model | Cutoff | Source |
|---|---|---|
| claude-opus-4-6 | 2025-05 (reliable; training data to 2025-08) | https://platform.claude.com/docs/en/models/opus-4-6/overview |
| claude-haiku-4-5 | 2025-02 (reliable; training data to 2025-07) | https://platform.claude.com/docs/en/about-claude/models/overview |
| gpt-5.2 | 2025-08-31 | https://developers.openai.com/api/docs/models/gpt-5.2 |
| gpt-5.2-codex | 2025-08-31 | https://developers.openai.com/api/docs/models/gpt-5.2-codex |
| gpt-5-mini | 2024-05-31 | https://developers.openai.com/api/docs/models/gpt-5-mini |

Not recorded:

- claude-sonnet-4-5: the current models overview no longer lists a cutoff for
  this id (it is a legacy entry); left unknown until the dedicated page is
  checked.
- gpt-5.2-mini: removed on 2026-09-12; retaining an undocumented model as a
  catalog alias target conflicts with the catalog's purpose of supplying valid
  model identifiers. `gpt-mini` now identifies the documented `gpt-5-mini`.
- gemini-3.1-pro-preview, gemini-3-flash-preview: the Gemini API model pages
  publish a "latest update" date, not a training cutoff.

## Context limits corrected 2026-09-12

The linked official pages for GPT-5.2, GPT-5.2-Codex and GPT-5 Mini each
document a 400,000-token context window and 128,000-token maximum output.
The catalog previously assigned 1,047,576-token windows to all three OpenAI
entries. These values are now corrected to the published limits. Unknown
model IDs still pass through requests unchanged; catalog removal is not an
API allowlist restriction.

This correction verifies these specific entries. It does not establish that
the entire catalog is current or that its best-first ordering includes the
latest available models; that broader section 8.1 audit remains open.

## Current general-purpose entries added 2026-09-12

| Model | Reliable cutoff | Context | Maximum output | Source |
| --- | --- | ---: | ---: | --- |
| claude-fable-5-1 | 2026-06 | 1,000,000 | 128,000 | [Anthropic overview](https://platform.claude.com/docs/en/models/overview) |
| claude-opus-5 | 2026-05 | 1,000,000 | 128,000 | [Anthropic overview](https://platform.claude.com/docs/en/models/overview) |
| claude-sonnet-5 | 2026-01 | 1,000,000 | 128,000 | [Anthropic overview](https://platform.claude.com/docs/en/models/overview) |
| gpt-6-astra | 2026-04-30 | 1,050,000 | 128,000 | [OpenAI model page](https://developers.openai.com/api/docs/models/gpt-6-astra) |
| gemini-3.8-flash | Unknown | 1,048,576 | 65,536 | [Google model page](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash) |

These entries advertise tool, vision, and reasoning support. Current entries
precede retained older entries, so `get-latest-model` selects Fable 5.1, Astra,
and Gemini 3.8 Flash for their respective providers. This is advisory ordering,
not a claim of benchmark superiority or account access. Existing aliases keep
their prior targets; `fable` and `astra` are new aliases. Explicit model IDs
continue to pass through without requiring catalog membership.

Catalog presence is not integration proof. [Fable 5.1's documentation](https://platform.claude.com/docs/en/models/fable-5-1/overview)
requires adaptive thinking and rejects forced tool use; request-fixture coverage
for those behaviors is now recorded in `anthropic-modern-model-audit.md`.
Google's page likewise lists specific
thinking levels. Older retained entries still require a complete limit and
deprecation audit. LLM tests (83/496), context-capacity tests (16/77), and build
pass; no live model calls or full-suite run were made for this refresh.

Omitted-model dispatch is now covered separately in `default-model-audit.md`:
the final provider selects the catalog default after middleware, while explicit
and adapter-configured models take precedence.

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

Not recorded:

- claude-sonnet-4-5: the current models overview no longer lists a cutoff for
  this id (it is a legacy entry); left unknown until the dedicated page is
  checked.
- gpt-5.2-mini: OpenAI publishes no page for this id. The catalog entry is
  kept as an alias target but carries no cutoff.
- gemini-3.1-pro-preview, gemini-3-flash-preview: the Gemini API model pages
  publish a "latest update" date, not a training cutoff.

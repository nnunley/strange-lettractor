# Live coding conformance and publication

**Goal:** Execute original coding-agent §§9.12–9.13 against available native
providers, preserve honest evidence for unavailable cells, then push the
authorized verified work.

**Architecture:** Reuse the fifteen existing parity journeys. Add the missing
seven-step smoke journey in one persistent session and temporary directory,
with step-local observations and deterministic proof controls. A named live
suite selects native providers, loads the existing dotenv configuration, writes
redacted evidence and reports missing credentials as incomplete, never passing.

**Scope:** Coding-agent conformance, not the separate unified-client live429
requirement. Existing unrelated work is preserved; publication scope is being
clarified while verification proceeds.

- [x] Run the existing parity matrix for available native providers.
- [x] Add same-session smoke source and mutation-sensitive deterministic tests.
- [x] Add a named live suite and validate provider selection without live calls.
- [x] Run the smoke journey against available native providers; investigate
  failures without converting model noncompliance into passing evidence.
- [x] Review evidence, update documentation, and run impacted checks.
- [ ] Commit and push all accumulated work through the full-suite pre-push gate.

OpenAI wire verification is accepted by the user for publication; its live run
is not required and is not a push blocker. Native OpenAI has no configured key.
The user additionally requested OpenAI coding checks through configured
OpenRouter. The existing `or-responses` overlay retains the OpenAI profile and
Responses protocol, with explicit `openai/gpt-5.2` and gateway provenance.
Anthropic and Gemini
keys are available after loading `.env`; secret values must never enter logs.
The smoke config uses a 10000ms session default and maximum, since Anthropic's
stock profile default is 120000ms. Calls must omit per-call timeout and actually
time out. This records an effective capped default, not a change to the profile.

Results: Anthropic and Gemini each have passing evidence for all fifteen parity
rows, combining initial runs and explicit targeted reruns. Gemini passes all
seven same-session smoke steps. Anthropic passes the first five, then returns
quota-exceeded during the subagent step; the closed session cannot run timeout.
No further Anthropic retries were made after that quota result. OpenAI remains
wire verified / live not run, accepted by the user for this publication.

Live validation found and repaired the missing string item schema on Gemini's
read_many_files paths array. Other reruns clarified prompts to demand the exact
file bytes and identical repeated calls already checked by the harness. Review
strengthened smoke proofs against output spoofing and inert/generated test code.
The expanded deterministic audit passes 261 tests / 2529 assertions / zero
failures or errors. Full verification is also enforced by the pre-push hook.

OpenRouter follow-up: `or-responses/openai/gpt-5.2` passes all fifteen parity
rows across the initial and targeted runs, and all seven same-session smoke
steps in `evidence/coding-conformance-1790550366776.edn`. Reports identify the
Responses protocol, OpenAI profile and gateway endpoint; this supplements the
accepted wire evidence without claiming direct first-party OpenAI access.

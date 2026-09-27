# Verification output

Tests, test runners, and reusable regression fixtures belong in Git. Generated
verification reports, model transcripts, and stage logs do not. Live runners
write to the ignored `evidence/` directory; CI may retain it as a job artifact.
Paths to that directory in audit notes describe local output, not files shipped
with a checkout. Historical committed reports remain available in Git history.

Use lgx 0.3.2 or newer. Run `lgx test` (also `lgx suite` or `make test`)
for deterministic checks. Run `lgx test test/attractor/<name>_test.lg` for
one file, or `lgx test-ns attractor.<name>-test` for the diagnostic namespace
runner. Live checks require a configured
provider and incur provider usage:

- `lgx live-coding-conformance` (or `make live-coding-conformance`): all fifteen
  coding-agent parity rows plus the seven-step smoke in one persistent session,
  for native OpenAI, Anthropic and Gemini. Loads `.env` using existing precedence.
  Missing native credentials produce blocked evidence and exit 3, not a pass.
  `ATTRACTOR_CODING_PROVIDERS=anthropic,gemini` selects an explicit subset;
  `ATTRACTOR_CODING_CHECKS=smoke` or `parity` reruns one portion. Model overrides
  use `ATTRACTOR_<ID>_MODEL`; `ATTRACTOR_PARITY_ROWS=parallel-tools,steering`
  selects parity rows, recorded explicitly alongside the complete available list.
  Otherwise the local catalog defaults apply.
  Reports are saved after each check under `evidence/coding-conformance-*.edn`,
  with in-progress status until the selection finishes. Exit 1 means a failed
  check; exit 0 means every selected check passed. A subset is not full parity.
  The smoke config explicitly caps default shell calls at 10 seconds, including
  Anthropic's otherwise longer profile default.

  To run the OpenAI profile and Responses adapter through the configured
  OpenRouter credential, use the existing credential-free overlay:

  ```sh
  ATTRACTOR_CONFIG=test/live/openrouter_protocols.edn \
  ATTRACTOR_CODING_PROVIDERS=or-responses \
  ATTRACTOR_OR_RESPONSES_MODEL=openai/gpt-5.2 \
  lgx live-coding-conformance
  ```

  Explicit aliases require a model override and record gateway provenance;
  they do not become first-party native evidence. Native provider IDs retain
  their protocol and endpoint checks.

- `make live-parity`: coding-agent tasks selected by `ATTRACTOR_LIVE_MODEL`.
  Optionally select rows with `ATTRACTOR_PARITY_ROWS=error-recovery,provider-edit-format`.
  Reports use a timestamped filename under `evidence/parity-matrix-evidence/`.
- `make live-matrix`: unified-client journeys. See the Makefile for
  the available live targets and `test/live/provider_matrix.lg` for selectors.
- `test/live/attractor_smoke.lg`: runtime smoke with stage artifacts under
  `evidence/runtime-smoke-evidence/`.

For the original coding-agent specification audit, run **`lgx audit-coding-loop`**
(or `make audit-coding-loop`). Its namespace selection lives in `lgx.edn`, uses
the existing runner and a four-minute diagnostic deadline, and includes native
scripted wire tests plus regular `coding_loop_audit_test.lg` and
`execution_scope_test.lg` regressions. It does not
make live provider calls. Process inspection and local loopback listeners must
be available for the fixtures and cleanup checks.

After the 2026-09-27 live-runner follow-up this suite passed 261 tests / 2529
assertions, zero failures/errors (exit 0). The earlier repair checkpoint was
233 tests / 2380 assertions. Historical red evidence was 220 tests / 2248
assertions, six failures and zero errors (exit 1), reproducing four defects
against a separately passing 216-test baseline. No failures were exempted.
See the [audit report](coding-loop-audit-2026-09-27.md) for repair evidence,
custom-environment cancellation limits and remaining live evidence. The new
regressions now participate in normal `lgx test` discovery; the old probe
entry point is a compatibility wrapper. The pre-live-runner full `lgx test` checkpoint passed **1566 tests /
14159 assertions, zero failures, exit 0**. Log:
`/tmp/attractor-coding-repairs-full-20260927.log`.

The provider matrix uses catalog defaults for native protocols, including
configured aliases. `ATTRACTOR_<ID>_MODEL` overrides the selection; compatible
endpoints require an explicit model. Reports record the chosen model and its
source, selected and available journeys, and an `:aggregate_status`.
Exit 0 means the selected applicable journeys are complete; intentionally
unsupported compatible capabilities may be skipped. Exit 1 means a journey
failed. Exit 3 means no targets ran or applicable evidence is incomplete.
In particular, `rate-limit` makes one request with retries disabled: an actual
retryable HTTP 429 proves that row, while HTTP 200 leaves it skipped/unproved
with a reason and makes the aggregate incomplete. The runner never loops to
exhaust an account. Scripted native responses prove orchestration and error
normalization; they do not prove live account access or a native rate limit.

Record the command, date, result, and material limitations in concise review or
release notes. Retain raw output locally or in CI when investigation needs it.
Promote a captured response into a regression fixture only when a test uses it
to verify behavior. A green subset does not establish the full specification.

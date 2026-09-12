# Usage aggregation

`attractor.llm/add-usage` implements the pinned unified spec §3.9 addition
contract for standard token fields. Required input, output and total counts
are summed. Optional reasoning, cache-read and cache-write counts treat an
unknown operand as zero when the other is known; two unknown values remain
nil. Missing optional fields follow the same rule.

High-level `generate` uses this operation to produce `:total_usage` across
tool rounds. Each `StepResult.usage`, the final `:usage` and response remain
unchanged. `:raw` provider metadata is available on those original usage maps;
it is not included in aggregate totals because provider metadata has no common
addition operation.

The 2026-09-12 audit found generation using `merge-with +` on entire usage
maps. Two otherwise successful tool rounds crashed on either `nil + nil` or
map + map for `:raw`. The regression drives the public generate API with an
active tool and a continuation response, covering all four known/unknown
operand combinations and separate raw metadata for each step. Fifteen
assertions failed before the fix; both tests now pass all 16 assertions.
The existing LLM namespace passes 83 tests/495 assertions and the CLI builds.

These checks establish client aggregation, not the accuracy of counts supplied
by a provider. Live comparisons against raw provider counters remain a distinct
provider-matrix obligation.

## Live counter mapping

The `usage-accounting` journey now reads the final response's raw provider
usage and independently constructs the expected normalized fields. It compares
input, output, total and cache counters, plus exact reasoning counts where the
protocol reports them. It requires positive input/output counts and rejects
missing raw evidence. Anthropic's estimated reasoning count is not compared to
an exact raw field that the protocol does not provide.

Both Responses and Messages gateway runs pass:
[retained raw and normalized counters](provider-usage-protocol-evidence.edn).
Regression fixtures cover all three native mappings, reject a wrong input/output
split with a plausible total, and reject absent raw data. Combined provider
evidence checks pass 7 tests/39 assertions. This verifies adapter fidelity to
the provider-reported counts, not independent tokenization or billing accuracy.
Gemini's native live comparison remains pending.

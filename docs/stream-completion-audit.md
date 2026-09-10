# Native stream completion audit

At baseline `5e811b1`, all three native adapters emit text and reasoning end
events without the final accumulated segment value required by the pinned
[unified LLM spec §3.14](upstream/strongdm-attractor/unified-llm-spec.md).
The event record in §3.13 is illustrative and does not list completion-value
fields; §3.14 explicitly requires those values. The existing compatible-adapter
reasoning fix uses `:reasoning`, keeping `:reasoning_delta` incremental-only.
Use `:text` analogously for completed text.

## Reproduction

Run from the repository root with the local Go-based runtime:

```sh
/Users/ndn/development/let-go/lg -source-paths src test/probes/stream_completion_check.lg run
```

This calls the public `llm/stream` API with an injected, offline SSE transport.
It sends two reasoning chunks and two text chunks per native provider. It makes
no network requests, needs no real credentials, and prints EDN records.

Observed on 2026-09-07: exit **1**, six failed completion checks. OpenAI,
Anthropic and Gemini each emitted the expected deltas, one end event per kind,
and a finish event. Each text end lacked `:text`; each reasoning end lacked
`:reasoning`. Thus successful final generation and correctly accumulated deltas
do not establish the segment-completion contract. The default suite's previous
green result did not cover these fields.

The probe is outside the default suite as a small diagnostic companion.
It is not a provider parity test: there is no real HTTP transport, live model,
tool-call coverage, cancellation, or concurrent-segment coverage in this probe.

## Original root cause and repair requirements

- Anthropic already accumulates text/thinking in its indexed block state, but
  `content_block_stop` emits only type, ID and raw metadata.
- Gemini already accumulates text/reasoning in stream state, but its finish
  path omits those values from end events.
- OpenAI tracks started/ended IDs without accumulating text/reasoning deltas.
  Its text-done, reasoning-done, content-part-done and message-item-done paths
  omit completed values. Review segment identity (including content indices)
  before introducing a buffer keyed only by item ID.

The repair must cover all applicable completion paths, not just the exact
fixtures above. Permanent tests should verify interleaved segment isolation,
empty segments, authoritative done payloads versus delta accumulation, duplicate
completion suppression, and preservation of final response/tool/usage data.
Redacted Anthropic thinking must remain opaque; do not invent visible reasoning
from encrypted data or expose it as ordinary text. Check compatible-adapter
text completion too; its earlier fix addressed only reasoning.

The initial audit changed no production code or let-go runtime. This is a
reproduced Attractor normalization gap, not an upstream let-go bug. The full
implementation goal remains incomplete.

## Protocol cross-check

The [official OpenAI streaming event reference](https://developers.openai.com/api/reference/resources/responses/streaming-events)
was fetched on 2026-09-07. Text and reasoning-text deltas/done events identify
both the item and its content index. Done events carry full text; content-part
done carries the finalized part, and item-done carries the item's content array.
Reasoning summaries use a separate summary index. This supports buffering by
segment rather than item alone and testing completion through each event path.
The field names of normalized completion values remain an Attractor API choice
guided by the pinned typed-completion requirement, not OpenAI wire field names.

## Implemented contract

Text end events now carry `:text`, and reasoning end events carry `:reasoning`,
across the three native adapters; compatible text completion is also covered.
OpenAI buffers individual content parts, uses explicit done values (including
empty strings) when present, and otherwise falls back to initial text plus
accumulated deltas. Direct, part and item completion paths share deduplication.
Item completion also closes known segments when its content array is omitted.
Anthropic redacted reasoning contributes no plaintext; its opaque representation
is retained in the existing raw/final-response paths.
OpenAI summary/encrypted-only item completion retains its existing raw
`provider_event` passthrough; it does not manufacture reasoning text events.

OpenAI index-zero IDs retain their item ID unless it begins with the reserved
`segment:` prefix. Other IDs encode the item length, item ID and content index.
Consumers should treat IDs as opaque correlation keys, not parse their spelling.
End values are never repeated under the delta keys, and existing accumulators
continue to append only delta events.

The permanent `attractor.stream-completion-test` namespace covers this contract
through the public high-level streaming API with offline provider transports.
`test/runner.lg attractor.stream-completion-test` is a direct/bundled entrypoint for the same tests.
Native duplicate transport-packet handling and OpenAI reasoning-summary event
normalization remain separate streaming work; this change does not establish
full streaming conformance, live provider parity, or complete Attractor support.

## Mechanical verification

- Initial permanent tests: 3 tests, 36 assertion failures, zero errors before
  implementation. Expanded tests then caught ID-collision and fallback gaps.
- Review caught lost opaque-item passthrough; the added regression produced
  six assertion failures before the corrective change.
- Final focused tests: 11 tests, 143 assertions, zero failures/errors, exit 0.
- Final worktree full suite: 588 tests, 4,923 assertions, zero failures, exit 0.
- Fresh main full suite after integrating `6353f57`: the same 588/4,923/0, exit 0.
- Combined LLM/Qwen/completion tests: 101 tests, 694 assertions, zero failures.
- The same 11/143 checks pass in a standalone bundle run from `/tmp`, exit 0.
  This is packaged let-go bytecode evidence, not native Go AOT lowering.
- Original six-check probe: all three providers pass, exit 0.
- `lgx build` and the rebuilt CLI's `help` command both exit 0.
- Independent spec and quality reviews approve after the passthrough repair.

Bundle verification commands (choose an existing temporary destination):

```sh
/Users/ndn/development/let-go/lg -source-paths src:test -b /tmp/stream-completion-check test/runner.lg attractor.stream-completion-test
```

Run that binary with `run` from outside the checkout. The explicit entrypoint
requires both the implementation and test namespaces so test discovery survives
bundling, and returns a failing exit status when any assertion fails.

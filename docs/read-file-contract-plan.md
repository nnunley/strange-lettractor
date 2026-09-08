# Shared read_file: text, binary rejection, and image continuation

Source: coding-agent specification §3.3 `read_file`, §5 output truncation, and
the existing unified SDK's multimodal tool-result encoding. This is CAL-TOOLS-01
read-file work, not proof of provider-reference prompt/schema fidelity.

## Observed gap

The local environment always slurps and line-numbers input, including binary
images. Agent tool execution then stringifies every structured executor result.
The SDK already encodes raw `:image_data` tool results for all three providers,
but real agent `read_file` cannot produce/preserve such a result.

## Required behavior

- Text remains line numbered (`N | content`), defaults to offset 1/limit 2000,
  respects explicit ranges and preserves Unicode. Missing/unreadable files remain
  model-visible tool errors. Non-image binary data must not become numbered text.
- Detect PNG, JPEG, GIF and WebP from byte signatures,
  not extensions. Return full encoded image bytes and detected media type with
  a short textual description. Unsupported binary is an explicit tool error;
  no image transcoder, SVG rendering, or network fetching is introduced.
  These are implemented reader formats, not a promise that every provider/model
  accepts every format. Wire tests prove encoding only; unsupported model input
  remains subject to provider errors. Other image formats remain unimplemented.
- Represent new image output as a serializable map containing `:content`,
  `:image_base64`, and `:image_media_type`. Extend the SDK's existing image-result
  helper to accept that explicit base64 form (including string-keyed fields),
  retaining the raw `:image_data` API. Reject conflicting/invalid image sources
  clearly; never silently double-encode base64 or stringify image bytes as text.
- Support an ordered `:images` vector of attachment maps for Gemini's affected
  `read_many_files` consumer. Each item uses the same image source/media fields;
  encode every image through each SDK adapter's existing multimodal tool-result
  path. Mixed batches include path-labeled text and image descriptions in input
  order, with attachment order matching image occurrence order. Preserve existing
  text-only batch output. Do not recursively reinterpret arbitrary vectors/maps.
- Explicit image-source field presence (`image_base64`, legacy `image_data`, or
  `images`, accepting keyword/string keys) discriminates attachment output.
  Agent attachment output requires string `content`; reject conflicting aliases,
  singular/plural coexistence, missing or invalid sources, non-string/empty media
  types, and invalid base64. Preserve the unified spec's nullable legacy fields:
  raw `image_data = nil` means no raw source; absent/nil media type defaults PNG.
  Explicit `image_base64 = nil` is malformed, unlike the legacy nullable raw field.
  Legacy SDK raw data keeps its default PNG media type;
  newly produced local images always supply detected media type. Agent validation
  happens before post hooks/history and inside the executor-error boundary.
  This stricter agent contract does not tighten the existing SDK content API:
  legacy raw SDK images may omit content or use structured content (existing
  provider-safe serialization). Preserve each adapter's omitted-content encoding:
  empty text for OpenAI/Anthropic, `functionResponse.response.result = null` for
  Gemini, independently observed on public base `892db06`. Add regressions for
  both omitted and structured content; do not normalize away this difference.
- Agent tool results retain the attachment separately from text truncation.
  Ordinary map/scalar executor output is unchanged. Validate image result shape
  within tool-error handling so malformed output cannot crash the whole session.
  Hooks receive the complete serializable raw map, and events retain full image
  evidence without inserting its base64 into the model's text content.
- Keep arbitrary bytes intact during image classification. For nonimages validate
  UTF-8 and reject NUL/binary controls while allowing ordinary text whitespace.
  Use let-go primitives; no handwritten Go fixture or runtime modification.

## Mechanical evidence

1. Permanent RED: actual local read_file image/binary handling and actual agent
   continuation through provider recording transports show the missing behavior.
2. Text ranges/default 2000 lines, offsets beyond EOF, Unicode, empty/missing/unreadable or directory
   inputs; non-image binary errors, supported signatures, extension mismatch.
3. Known image fixture bytes pass from local file through each built-in profile
   and the agent loop into actual OpenAI/Anthropic/Gemini encoded request bodies.
   Decode the wire image and compare exact bytes/media type and call identity.
4. Text-only truncation leaves image payload intact; raw hooks and events agree;
   malformed explicit image results become tool errors. Ordinary map results and
   existing raw-byte SDK image inputs keep their behavior.
   Mixed/batch image order and file identity survive actual Gemini continuation;
   text-only batches retain their prior representation. Test plural encoding for
   all three adapters and conflicting keyword/string aliases explicitly.
5. Focused/impacted/full sentinel, standalone bundle and CLI build/help; paired
   scope/spec/quality and final component audit before commit/push.

Live vision/model quality, provider reference-asset parity, other tools, and the
broader coding-agent specification remain separate requirements.

Implementation order: local reader classification and permanent RED/GREEN tests;
explicit singular/plural SDK attachment validation/encoding with legacy tests;
agent and Gemini batch propagation plus full continuation/hook/event tests.

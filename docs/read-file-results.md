# File reads and image tool results

The local `read_file` operation returns line-numbered text with a default
2,000-line limit. Text must be valid UTF-8 without binary control bytes; ordinary
whitespace is allowed. Missing files, permission denial and non-image binary
files become tool errors that the agent can recover from.

PNG, JPEG, GIF and WebP are recognized by byte signatures, not filename extensions.
Image reads return complete bytes as an EDN-safe attachment, independent of text
offset/limit options:

```edn
{:content "Image file (image/png)."
 :image_base64 "..."
 :image_media_type "image/png"}
```

Signature recognition is not image decoding or a promise that every provider/model
accepts that format. Other formats are not implemented by this reader. The
separate `read_text` environment operation continues returning unmodified bytes.

Agent attachments require string `:content`. An ordered nonempty `:images` vector
can contain multiple attachment maps. Gemini's mixed `read_many_files` output
uses this form, preserving path-labeled text, image occurrence order, and per-image
descriptions. Text-only batch output keeps its existing vector representation.
Ordinary maps, scalars and nested vectors are not recursively interpreted as images.

Only text is truncated. History/model requests retain full attachments; tool-end
events and post hooks retain the full normalized result, including descriptive
metadata. Legacy raw image bytes are converted to equivalent base64 before these
agent records are serialized. Conflicting aliases, invalid image sources, and
invalid attachment content become model-visible tool errors inside the executor
error boundary, before hooks or history receive malformed attachment output.

The SDK accepts keyword or string field names, new explicit `image_base64` and
`images` forms, and the existing `image_data` raw string/byte-array form. Nullable
legacy fields remain compatible: nil raw data means no raw source, and absent/nil
media type defaults to PNG. New explicit base64/plural fields cannot be nil.
Unlike the agent attachment contract, SDK tool-result content may remain structured
or omitted. Omitted content retains each provider's prior wire representation.

## Mechanical evidence

```sh
/Users/ndn/development/let-go/lg -source-paths src:test test/runner.lg attractor.read-file-test
/Users/ndn/development/let-go/lg -source-paths src:test test/runner.lg attractor.read-file-impacted-test
```

Focused and bundled evidence: 14 tests / 439 assertions. Impacted evidence:
217 / 1,667. The default suite passes 667 / 6,507, and CLI build/help pass.
All four formats have local signature/byte-preservation checks; PNG is the
representative image in all three agent/provider continuations, with PNG/GIF in
the Gemini mixed batch. JPEG/WebP do not yet have separate agent/wire fixtures.
See `read-file-contract-evidence.edn` for the baseline and regression history.
These are local-file, real-agent, native-hook and provider-encoding checks—not
live model acceptance, vision quality, full provider-reference fidelity, or
native-Go AOT parity.

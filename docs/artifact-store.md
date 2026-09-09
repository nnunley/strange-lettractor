# Artifact storage and run metadata

The public store API is in `attractor.context`: `make-artifact-store`,
`store-artifact!`, `retrieve-artifact`, `has-artifact?`, `list-artifacts`,
`remove-artifact!`, and `clear-artifacts!`.

The backing threshold is 102,400 bytes. Strings use UTF-8 payload size; other
supported values use their serialized EDN size. Values above that threshold use
`artifacts/<id>.edn` when the store has a base directory. Values at the threshold,
or without a base directory, remain in memory. Metadata includes ID, name, size,
storage time, and backing status. Artifact values must round-trip through the
supported non-evaluating EDN reader.

Set values round-trip on the local runtime's data reader (2026-09-08); on a
released let-go without it they would still be rejected, see
[let-go #823](https://github.com/nooga/let-go/issues/823) and
`let-go-set-reader-gap.md`.

New run metadata is written to root `manifest.edn`; this is separate from the
immutable captured workflow's `workflow/manifest.edn`. Existing root JSON
manifests are not removed or migrated. The external stage-status contract still
requires `<node_id>/status.json`. Checkpoints use `checkpoint.edn`.

A handler can create/use a store under the supplied run root and return artifact
metadata in its outcome. Registrations persist in `artifacts/index.edn` (written
atomically on every store/remove/clear): metadata for each artifact, the value
itself for inline artifacts, the file path for file-backed ones. Opening a new
store over the same root reconstructs them, `discover-artifacts` lists them
from run state without a store, and `checkpoint-artifacts` reads the metadata
handlers returned in their outcomes, which survives resume (ATTR-ART-02,
`SCN-ARTIFACT-DISCOVERY`).

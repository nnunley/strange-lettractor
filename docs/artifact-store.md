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

Set values currently fail that check because the local reader returns a
`hash-set` form, not a set. This known limitation is tracked in
[let-go #823](https://github.com/nooga/let-go/issues/823); see
`let-go-set-reader-gap.md`. Full Clojure data-reader conformance is not claimed.

New run metadata is written to root `manifest.edn`; this is separate from the
immutable captured workflow's `workflow/manifest.edn`. Existing root JSON
manifests are not removed or migrated. The external stage-status contract still
requires `<node_id>/status.json`. Checkpoints use `checkpoint.edn`.

A handler can create/use a store under the supplied run root and return artifact
metadata in its outcome. This does **not** create a persistent discovery index:
the store's registration map is process-local, and opening a new store does not
reconstruct prior registrations. General run-result inventory and reconstruction
on resume remain tracked by ATTR-ART-02 / SCN-ARTIFACT-DISCOVERY.

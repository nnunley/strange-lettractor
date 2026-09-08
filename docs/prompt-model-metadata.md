# Session prompt model metadata

Coding-agent spec section 6.3 requires model display name and knowledge cutoff
in the environment block. The previous implementation omitted cutoff entirely
and rendered the raw model ID. Model routing itself was correct.

The session now snapshots optional trusted profile `:display_name` and
`:knowledge_cutoff`. Nonblank strings override advisory catalog fields of the
same name. Catalog fallback is allowed only when its provider matches the active
profile, including when looking up an alias. Unavailable display names fall back
to the actual model ID; unavailable cutoff is rendered explicitly as `unknown`.
Neither raw snapshot `:model` nor request `:model` is changed by these labels.

These are profile metadata, not prompt-derived/model-generated configuration.
For example, a custom profile may carry `:display_name "Local Model"` and a
verified `:knowledge_cutoff` string. No remote lookup occurs at session creation.
The existing catalog has no verified cutoff fields: the new fallback is honest
missing-data behavior, not proof of complete provider catalog metadata. Adding
real cutoff dates requires sourced catalog work; do not infer dates from names.

## Mechanical evidence

`test/attractor/prompt_metadata_test.lg` captures actual two-turn session requests
with controlled environment inspection and completion. It checks git branch,
changed-file count, recent messages, platform/OS/date, stable snapshots, profile
override/catalog/alias/provider-mismatch cases, blank/nonstring fallback, unchanged
request model IDs and final user override. Synthetic cutoff dates are fixture
data only. All sessions close in finally; no model credentials are needed.

Run: `/Users/ndn/development/let-go/lg -source-paths src:test dev/prompt_metadata_tests.lg run`.

- RED: 3 tests / 26 passing / 40 failing assertions / zero errors.
- Native GREEN and outside-checkout bundle: each 3 tests / 66 assertions /
  zero failures or errors. CLI build/help also passed.
- Actual Claude implemented the single production-file change through the
  framework connector. Main owns tests, source inspection and verification.
- Full default suite: 722 tests / 6,992 assertions / zero failures, exit 0.
  Independent bounded Claude spec/correctness review approved the change.

This fixes the two prompt metadata defects. Complete catalog facts and full
Attractor/provider conformance remain separate obligations.

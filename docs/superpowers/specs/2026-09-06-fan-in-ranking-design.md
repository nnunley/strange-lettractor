# Prompted and heuristic fan-in

User-approved detailed contract (2026-09-06) within ITER-0006. This component
implements StrongDM Attractor §4.9 and ATTR-FANIN-01; it does not complete the
iteration or the unified framework.

## Evidence and alternatives

At `1e1950d`, `handlers/handle-fan-in` ignores the node prompt and candidate score.
It filters to SUCCESS/PARTIAL_SUCCESS and chooses by status then ID. StrongDM's
heuristic explicitly orders SUCCESS, PARTIAL_SUCCESS, RETRY, FAIL, then descending
score and ascending ID. The final prose requires FAIL when all candidates fail.

Independent native probe at this revision: two SUCCESS records `(a, score 1)` and
`(z, score 9)` select `a` even with a higher-score prompt; a lone RETRY record
returns `All parallel branches failed`. These are observed behavior gaps, not
yet test-first regression evidence or implemented fixes.

Recommended: a small fan-in unit with a pure selector and injected ranker; a
separate adapter invokes the existing unified LLM client. This supports offline
contract tests and real provider use without embedding provider-specific code in
handlers. A callback-only implementation would leave default prompted workflows
unimplemented. Embedding model calls directly in the existing large handlers file
would entangle selection validation with transport configuration.

## Selection contract

Read the existing `parallel.results` vector without mutating it. Empty results
return FAIL. Eligible candidates are SUCCESS, PARTIAL_SUCCESS, and RETRY;
FAIL/CANCELLED are not winners. An entirely ineligible set returns FAIL without
calling the model. RETRY remains eligible to follow the explicit upstream ranking;
choosing it makes the fan-in selection itself SUCCESS, not a branch retry.

Candidate records retain their existing top-level `:status`, optional `:score`,
`:id`/`:node_id`, and `:context_updates` fields, not a new nested `:outcome` shape.
Attach the original zero-based occurrence index to each request envelope, not to
the persisted candidate. Pass the complete candidate record as data to the ranker.

An empty or whitespace-only prompt chooses by status rank, descending numeric
score (missing score is zero), then string ID. Non-numeric present scores fail
explicitly rather than silently changing order. Original edge occurrence breaks
otherwise identical ties. Preserve the existing winner context keys and string
status representation for compatibility.

Score validation applies only to heuristic selection; prompted ranking may evaluate
arbitrary candidate evidence and does not sort or interpret the score field.

A nonblank prompt uses the ranker exactly once per handler attempt. Its request
contains the node, prompt, ordered eligible candidate records and original indices,
and cancellation predicate; it does not expose a mutable parent context. Its return
value is an original candidate index, not an ID: duplicate branch target IDs are
legal and must not make selection ambiguous. Validate integer membership before
publishing any winner updates. Invalid output is a non-retryable configuration
failure. Ranker exceptions remain exceptions for the engine's existing retry
classification. Cancellation checked before and after ranking wins over selection.
There is no silent heuristic fallback on model errors.

## LLM and engine boundary

Provide a ranker factory backed by `attractor.llm/generate-object`, requesting one
integer candidate index. Candidate data is clearly separated from the evaluation
instructions, and the response is validated both structurally and against actual
eligible indices. JSON is only the external model response format; persistence
remains EDN. No tools or agent loop are needed for ranking.

The response object is exactly `{"candidate_index": integer}` with that field
required and additional fields disallowed. Read the string-keyed output produced by
the JSON decoder. Translate `generate-object`'s `:no-object-generated` error into
a non-retryable invalid-ranking error while retaining its cause. Do not reclassify
provider/transport errors or local cancellation. Test malformed JSON, schema-invalid
objects, and structurally valid but ineligible indices as distinct cases.

The adapter takes an injected unified client and model defaults; node-resolved
`llm_model`, `llm_provider`, and reasoning settings override defaults consistently
with existing model configuration. Missing required model configuration fails
explicitly; do not invent a provider/model or return a mock winner. Pass the node's
cancellation predicate into generation and rely on existing attempt supervision
for timeout and joined cleanup.

Expose optional ranker configuration through the registry factory while preserving
its existing arities. The default fan-in handler uses the real adapter. Registered
custom fan-in handlers remain authoritative. Registry cloning, manager/child runs,
and pinned resume must preserve injected ranker closures; closures are runtime
configuration and must never enter workflow captures or checkpoints. Prefer this
existing registry injection seam to adding another independent pipeline option.

CLI run/resume must supply its explicit `--model`/`--provider` overrides to the
ranker with the same override precedence as codergen. Explicit `--mock` must never
make a live ranking request: prompted fan-in reports that a real or injected ranker
is required rather than fabricating selection. Server/default-library use can take
node model configuration or an explicitly configured ranker. Do not infer a model
from the presence of credentials alone. The existing codergen fallback model is
not a new fan-in default. Add CLI override/mock contract tests.

## Proof obligations

Direct tests cover status/score/ID/occurrence ordering, RETRY eligibility, missing
scores, invalid scores, empty/all-ineligible input, blank prompts, and no mutation.
Ranker tests cover prompt/data fidelity, exactly one call, duplicate IDs, invalid
indices, thrown errors, and cancellation without publishing updates.

Adapter tests use a real unified client with an in-memory provider adapter, inspect
the request/model/schema/cancellation handoff, and return controlled responses.
They must demonstrate that the prompt changes the selected winner; malformed or
out-of-range model answers cannot become success. These are offline transport
contract tests, not live provider parity.

Public DOT tests run start -> parallel -> branches -> fan-in -> exit with custom
branch handlers and the injected ranker. Prove selection contrary to heuristic,
checkpoint/context agreement, retained original candidate order, and ordinary
heuristic behavior when the prompt is absent. Include cloned registry and pinned
resume coverage, plus a held ranker cleanup barrier under cancellation/timeout.
No completion marker is added until independent spec and quality reviews approve
the implementation and evidence.

Run focused tests, the full default suite, and local let-go AOT sequentially.
Keep the five reader acceptance failures separately visible. Preserve the upstream
restoration checklist and private notes. Fan-in does not repair the upstream
async helper scope-ownership gap or implement executable skill packages.

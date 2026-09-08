# Deployment context-capacity discovery

Status: approved by the user on 2026-09-08. Implementation and evidence pending.

## Evidence and scope

The user requires discovery rather than a fixed Qwen context-window constant.
On 2026-09-08 the local llama.cpp `/props` response reported
`default_generation_settings.n_ctx = 131072`, `total_slots = 4`, and
`model_alias = qwen3.8-27b`. These are observations, not configuration defaults.
No server settings were changed.

The [llama.cpp server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)
describes `/props` generation settings separately from `/v1/models` metadata
such as `n_ctx_train`. Discovery must not substitute training capacity for the
active deployment setting, or multiply capacity by the slot count. Router-mode
property queries can select a model and control autoload; discovery must not
cause a model load solely to inspect metadata.

Current `llm/fetch-models` discards metadata and caches identifiers by provider
alone. This cache is not suitable for deployment capacity. Profiles currently
default to 128000, and `agent/check-context-usage!` uses that number for the
informational warning described by coding-agent-loop spec section 5.5.

The local runtime fix documented in `docs/let-go-http-cancellation.md` enables
bounded scope-owned HTTP operations. It is not yet an upstream runtime release.

## Proposed approach

Add an optional adapter capability for context discovery. The initial native
implementation recognizes llama.cpp on the selected OpenAI-compatible endpoint,
checks the selected model identity, and reads its active context setting. It
must use the same resolved endpoint and credentials as generation, not a global
provider-only cache or a guessed model name. Custom adapters can supply the
same capability; mock/injected completion paths remain offline by default.

Unless an explicit override is configured, refresh immediately before each model
request, after turn ownership is acquired. Overrides skip unnecessary probes.
This catches changes between tool rounds as well as between user inputs. Do not
hold the session lock during network I/O. A late discovery result must not
mutate a successor turn or closed session. Use bounded native scope cancellation
and join the discovery worker on timeout, abort, success, and failure.

Precedence: an explicit session context-window override, then validated live
deployment capacity, then advisory profile/catalog fallback. Record source,
model, endpoint identity, observation time, and unavailable/failure status as EDN
metadata. Do not expose credentials or raw server props in events or artifacts.
When a refresh fails, do not present a previous live result as fresh discovery.
Continue with an explicitly labeled estimate/unknown state and warning; a
caller may opt into requiring successful discovery.

The configured discovery time budget must be positive and bounded; the proposed
default is 1000 ms. Request timeout enforcement must not rely on unsupported
native `:timeout` or `:abort_signal` map options.

The existing approximate history-token warning consumes the selected capacity.
It is still an estimate, not an exact remaining-token counter. This change does
not add automatic compaction, truncate history, or claim a strict admission
guarantee. A server can restart after discovery and before generation; the
provider's context-length error remains authoritative in that race.

## Alternatives

- Session-start-only discovery costs fewer metadata requests but misses a
  restart or configuration change during a long-lived agent/tool loop.
- A time-to-live cache reduces metadata traffic but deliberately introduces a
  stale-capacity interval and needs endpoint/model/credential scoping.
- Pre-request discovery adds small metadata overhead but has the clearest
  freshness rule. This is the recommendation; cache optimization can follow
  measured cost without changing the metadata contract.

## Mechanical acceptance evidence

Tests must cover two capacities from successive observations, a capacity
decrease, separate endpoints/models, explicit override precedence, malformed or
non-positive capacity, unsupported endpoints, model mismatch, and refresh failure
after a previous success. Confirm no model-name constants and no slot-count
multiplication. Capture real agent warning events across tool rounds and prove
that a canceled predecessor cannot overwrite its successor's metadata.

Use a let-go-owned loopback fixture for held headers/body, cancellation, worker
join, and fallback. Run native and standalone-bundle tests, the full Attractor
suite, and a live read-only discovery against the local llama.cpp endpoint.
Unavailable native cancellation must fail a prerequisite check clearly, not
silently leave a worker or socket running.

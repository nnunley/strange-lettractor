# Deployment context capacity

Agent sessions refresh deployment capacity before each actual model request,
including subsequent tool rounds. Initial native discovery recognizes llama.cpp
on custom OpenAI-compatible endpoints. It uses the generation adapter's resolved
endpoint and credentials, verifies model identity, and reads active `n_ctx` from
`/props`, not training capacity or a slot-count multiple. Router requests select
the URL-encoded model and disable autoload.

An explicit session `:context_window_size` overrides discovery and skips probes.
Otherwise a validated live observation wins; failed refreshes revert to the
original advisory profile window, never the preceding live observation. Copied
session profiles preserve that original fallback too. An overflow response
reporting a smaller validated capacity still limits recovery and subsequent tool
rounds in that turn.

Session options:

- `:context_window_size`: positive integer override (at most `Long/MAX_VALUE`).
- `:context_discovery_timeout_ms`: integer 1–60000; default 1000 milliseconds.
- `:require_context_discovery`: fail before generation when no usable capacity
  can be obtained. An explicit override satisfies this policy.
- `:max_output_tokens`: generation output allowance; default 4096.
- `:context_reserve_tokens`: uncertainty allowance; default the greater of 1024
  and one tenth of the context window.
- `:context_max_summary_calls`: maximum calls per checkpoint; default 32.

Mock providers and injected completion/stream functions stay offline. Custom
adapters can provide `:discover_context`, returning a map such as:

```clojure
{:status :available :model "deployed-model" :context_window_size 65536
 :endpoint "http://model-host/v1" :observed_at 1788884000000}
```

Use `llm/client-discover-context` to invoke adapter callbacks within a bounded
scope, or `llm/discover-context` for direct provider discovery. Native `probe!`
and raw adapter callbacks are internal caller-owned operations, not standalone
timeout-enforcing entrypoints. Custom callbacks must cooperate with scope
cancellation; failure to join is an explicit error, not successful fallback.

The session's `:context_capacity` map labels source/status/model/window and
observation time. Safe endpoint provenance is retained for available observations;
userinfo, query strings, fragments, raw props, headers and exception messages are
not copied into this metadata. Unavailable discovery emits a warning. Request
admission uses an estimate of the assembled model request, including system
instructions, harness content, tool definitions and message history, with separate
output allowance and uncertainty reserve. Estimates are explicitly labeled; they
are not exact tokenizer counts or a guarantee against deployment changes between
discovery and generation.

Managed agent and summary requests reject native provider options that replace
their model, messages, tools or output limit. Configure the session's output
allowance with `:max_output_tokens`; unrelated sampling options remain supported.
Direct unmanaged unified-client calls retain their existing override behavior.

## Compaction and overflow recovery

In the console, `/context` shows the last request estimate and checkpoint status.
`/compact` requests a checkpoint before the next model request; it does not start
an independent turn. Attached clients use the same host operations,
`:session/context` and `:session/compact`.

Long sessions keep their complete in-memory transcript while sending a smaller
model-context projection. With a known capacity, admission can trigger compaction
before the hard limit; without one, a manual checkpoint reports an unavailable
capacity instead of guessing a safe bound. Compaction creates a bounded
model-generated checkpoint of older work, retaining current instructions and
recent complete tool exchanges.
Later compactions incorporate the preceding checkpoint. Tool calls and their
results stay paired; completed tools are not re-executed to rebuild context.

Summary requests also have input and output bounds. Failed, empty, oversized or
cancelled summaries do not replace the previous projection. An individual exchange
or fixed prompt/tool prefix that cannot fit produces a recoverable error; it is
not silently truncated. Lifetime token and turn accounting continues across
compaction, including the additional tokens spent on summaries.

The llama.cpp error type `exceed_context_size_error` is a context overflow even
when its numeric error code is `400`. A validated server `n_ctx` supplies the
effective limit for recovery when discovery or configuration was too optimistic.
Recovery must reduce the request and pass admission before retrying generation
once. Another overflow ends that attempt with a recoverable error. Streaming
attempts that already produced visible output are not automatically retried.

Compaction preserves the live environment, harness and complete transcript. It
does not make that transcript durable across process restarts or increase the
model's context window.

## Runtime and mechanical checks

Native discovery requires scope-aware HTTP client vars marked with
`:scope-cancellation true`. Until the local let-go fixes are upstream, use the
runtime documented in [HTTP cancellation](let-go-runtime-issues.md). Older
runtimes report `:runtime-prerequisite` without starting an HTTP request.

With `LGX_LG` set to the fixed runtime, run:

```sh
export LGX_LG="$HOME/development/let-go/bin/lg"
"$LGX_LG" -source-paths src:test test/runner.lg attractor.context-discovery-test
"$LGX_LG" -source-paths src:test test/runner.lg attractor.context-transport-test
"$LGX_LG" -source-paths src:test test/probes/context_discovery_http_check.lg run
"$LGX_LG" -source-paths src test/probes/context_capacity_check.lg http://model-host/v1 deployed-model
```

Loopback tests require permitted local sockets and OpenBSD-compatible `nc` for
the held-body relay. Response content/timing is let-go; the execution environment
owns and joins server/relay processes. Other loopback cases use native `http/serve`.
Bundle the session/transport runners with `-b` and run them outside the checkout
to verify standalone execution. The live checker only reads metadata.

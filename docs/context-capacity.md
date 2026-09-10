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
session profiles preserve that original fallback too.

Session options:

- `:context_window_size`: positive integer override (at most `Long/MAX_VALUE`).
- `:context_discovery_timeout_ms`: integer 1–60000; default 1000 milliseconds.
- `:require_context_discovery`: fail before generation when no usable capacity
  can be obtained. An explicit override satisfies this policy.

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
not copied into this metadata. Unavailable discovery emits a warning. Context
usage remains a history-based estimate; this does not compact history, provide
an exact remaining-token counter, or guarantee admission if the server changes
between discovery and generation.

## Runtime and mechanical checks

Native discovery requires scope-aware HTTP client vars marked with
`:scope-cancellation true`. Until the local let-go fixes are upstream, use the
runtime documented in [HTTP cancellation](let-go-http-cancellation.md). Older
runtimes report `:runtime-prerequisite` without starting an HTTP request.

With `LGX_LG` set to the fixed runtime, run:

```sh
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

# JSON integer precision loss

Upstream: https://github.com/nooga/let-go/issues/815

Observed 2026-09-07 with the local let-go binary (user-owned checkout HEAD
`bdd8268c9cb3acf369f0854bada47af79d1d673d`, potentially with local edits).

```clojure
(require '[json :as json])
(get (json/read-json "{\"id\":9007199254740993}") "id")
;; actual 9007199254740992, expected 9007199254740993
```

`pkg/rt/json.go` decodes JSON numbers through Go float64 and then converts
integral float64 values to VM integers. Exact integers above 2^53 can already
have been rounded before that conversion. This value is within signed int64
range, so the loss is not an unavoidable VM integer-range limitation.

Consider `json.Decoder.UseNumber` with explicit exact int64 conversion, retaining
intentional decimal/exponent behavior and defining out-of-range errors. Tests
should cover 2^53 boundaries, signed int64 limits, negative values, decimal and
exponent forms, and malformed inputs. No runtime source was modified here.

## Attractor return point

Codex's installed schema permits signed int64 JSON-RPC IDs. Generating small
client IDs does not solve incoming server request IDs: a rounded incoming ID
cannot safely be echoed back. Request correlation must not claim the full ID
contract until this is fixed or a verified exact decoder is used. Add a large-ID
wire regression when implementing `attractor.codex.rpc`; framing success alone
does not establish lossless numeric decoding.

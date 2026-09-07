# Mutable byte-array copying during Go interop

Upstream: https://github.com/nooga/let-go/issues/813

Observed 2026-09-07 with the local let-go binary; checkout HEAD was
`bdd8268c9cb3acf369f0854bada47af79d1d673d` (user-owned checkout may contain edits).

## Reproducer

```clojure
(require '[io :as io])
(let [r (io/string-reader "ABC")
      b (byte-array 3)]
  (println :n (.Read r b) :actual (vec b) :expected [65 66 67]))
```

Actual: `:n 3 :actual [0 0 0] :expected [65 66 67]`.
The reader consumes the input, but mutations to the Go byte slice are not
visible in the original let-go array. The same result occurs with `.Read` on a
child process stdout pipe; this is not a subprocess-specific problem.

## Cause

`pkg/vm/native_func.go` function `boxArgForReflect` handles slice/array targets
by treating every `Sequable` as a sequence to copy with `unboxSliceInto`.
`TypedArray` implements `Sequable`, so its existing mutable Go slice returned
by `Unbox()` is not passed through. A correctly typed mutable byte-array should
retain its backing storage for calls whose contract mutates that buffer.

Potential upstream repair: preserve compatible typed-array backing slices
before generic sequence conversion. Keep vector/list conversion behavior and
add regression coverage for byte-array identity/mutation and other array types.
No runtime source was modified in this investigation.

## Attractor workaround and return point

Buffered single-byte reads do not require caller-owned mutable buffers:

```clojure
(let [r (.Buffered (io/string-reader "ABC"))]
  [(.ReadByte r) (.ReadByte r) (.ReadByte r)])
;; verified result: [65 66 67]
```

Use this boundary when implementing bounded Codex frame accumulation; do not
replace bounded framing with an unbounded line reader. Revisit chunked reads
after an upstream fix, with a regression proving the caller's array changes
and a split-UTF8 protocol test. EOF/error propagation and AOT remain separate
transport verification obligations.

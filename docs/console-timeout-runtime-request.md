# let-go capability request: deadline-aware line input

This is an enhancement request, not a claim that Clojure `read-line` requires a
timeout argument. Attractor's ConsoleInterviewer needs a nonblocking, bounded
line read while keeping let-go as the implementation language.

## Observed on local let-go

The current `read-line` implementation in `pkg/rt/iort.go` calls the IOHandle's
buffered `ReadString('\n')`. It has no deadline/cancellation option and treats
all returned errors as EOF or partial-line completion. Wrapping that call in a
timed future does not cancel the underlying read: an abandoned reader can consume
a subsequent question's answer.

`term/key-pending?` and `term/read-key` are not equivalent line-input primitives:
they use `*keys*` and the native process-wide `keyBuf`, separate from `*in*` and
its buffered reader. Native readiness counts available bytes, not EOF readiness.
The key interface also handles synthetic terminal events.

Bounded reproduction (both commands exit normally):

```sh
printf '' | lg -e '(require (quote [term :as term])) (prn {:pending_at_eof (term/key-pending?) :read_at_eof (term/read-key)})'
printf 'first\nsecond\n' | lg -e '(require (quote [term :as term])) (dotimes [_ 13] (prn {:pending (term/key-pending?) :key (term/read-key)}))'
```

The first prints `{:pending_at_eof false, :read_at_eof nil}`. The second confirms
that consecutive lines are held by the key-source buffer, so switching back to
`read-line` is not a safe per-question timeout strategy.

## Requested capability

A native, EOF-aware deadline/cancellation-capable line reader available to let-go
code, with explicit line/EOF/timeout outcomes and real read errors preserved.
Timed and untimed operations must share input ownership and buffering, honor the
selected input handle (including `*in*`), and not leave a worker reading after a
timeout/cancellation result. No JVM-specific interface is requested.

Please define partial-line behavior across timeout, support canonical TTYs and
pipes, and retain LF/CRLF, final unterminated lines, and staggered UTF-8 bytes.
An owned reader object with explicit close/dispose may be preferable to changing
the established `read-line` return contract; API shape is left to let-go.

Proof should include repeated timeouts followed by an answer, mixed timed/untimed
reads, buffered consecutive lines, EOF, partial lines and split UTF-8/CRLF, plus
cancellation/cleanup with no stale reader consuming later input.

# Shared queue interviewers

`make-queue-interviewer` accepts an ordered collection of answers. Answer maps
are returned intact; scalar entries (including `false` and `nil`) are consumed
and normalized to `:value`/`:text` maps. Exhausted queues use the question's
`:default`, or return `:skipped`. The default-on-exhaustion policy is an existing
project extension to StrongDM's queue pseudocode.

Concurrent calls through the **same QueueInterviewer instance** claim each answer
once. FIFO means claim order, not a predetermined assignment to parallel branches.
RecordingInterviewer preserves question/answer pairs; concurrent recording order
is completion/append order, not guaranteed invocation order.

The existing one-argument `->QueueInterviewer` constructor remains available for
an answer atom. Its lock belongs to the interviewer instance: multiple instances
wrapping the same atom, or direct external mutations of that atom, are not
coordinated. Share the interviewer itself with parallel consumers.

A narrow boolean-CAS lock currently guards dequeue because local let-go's native
atomic-update alternatives have the defects tracked in
[let-go #824](https://github.com/nooga/let-go/issues/824). No input waiting,
callback or recording happens inside the critical section. Restore a native
atomic dequeue only after the upstream contracts and these regressions pass.

This does not implement ConsoleInterviewer deadlines; those remain tracked by
ATTR-HUM-02 and let-go #822.

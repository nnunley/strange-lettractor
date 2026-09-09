# Console timeout — ATTR-HUM-02 (resolved 2026-09-08)

Resolution: the standalone `ConsoleInterviewer` now reads from one owned line
source (`attractor.interviewer/start-line-source!`: a reader future feeding a
channel) and takes each answer with `alts!` against a timeout channel. This
satisfies the design review's constraints below without a runtime change:
there is no per-question reader to abandon, timed and untimed questions share
one reader and buffer, type-ahead across answered questions is preserved,
input arriving after a timeout is discarded before the next question, and EOF
yields SKIPPED. The stdin reader future stays parked until the process exits,
which the CLI accepts; embedded frontends pass their own line channel to
`make-console-interviewer`. Evidence is recorded in the Attractor requirements
ledger (`SCN-HUMAN-TIMEOUT`). nooga/let-go#822 remains a nicety, not a blocker.

The original discovery notes follow for history.

Source: vendored StrongDM Attractor spec §§6.2, 6.4–6.5. A question's
`timeout_seconds` bounds input waiting; use the complete `default` answer when
provided, otherwise return `:timeout`. Preserve existing question rendering and
answer selection. The handler's `human.default_choice` routing is already tested
with injected timeout answers, not native elapsed-time evidence.

Fresh public baseline `f9f7b30`: 644 tests / 5,970 assertions / zero failures.
Native PTY reproduction asked a freeform question with a 0.05-second timeout.
The process remained blocked after a one-second observation and returned only
after explicit input release, reporting 7,782 ms. The exact process was released
and exited zero; no reader/process was abandoned. This confirms the Attractor gap.

## Design review outcome

Do not implement a timed future around blocking `read-line`, or switch per question
between `read-line` and terminal key reads. The former leaves an active reader;
the latter has separate buffering and input binding. Inspection and native EOF
probes identified a runtime capability dependency, documented in
`console-timeout-runtime-request.md`. Filed upstream as
[nooga/let-go#822](https://github.com/nooga/let-go/issues/822), an enhancement rather
than a Clojure compatibility defect. No let-go runtime files have been modified.

The direct native file-deadline alternative was also checked without launching a
read: `(.SetReadDeadline (.File *in*) (.Add (now) 1000000))` returned
`file type does not support deadline` on an allocated PTY (and ordinary tool
stdin). Both probes exited zero; no input flags or blocked workers were retained.

Next design needs an EOF-aware, deadline-capable owned line-input seam. Keep
rendering and answer parsing separate from input outcomes (`:line`, `:timeout`,
`:eof`), but do not claim native completion from an injected adapter. Settle how
partial input is owned/discarded across timeout before implementation. Native
default input must preserve buffered consecutive lines and mixed timed/untimed
prompts; preserve the existing bound-input behavior.

## Required evidence once the input capability is available

- Real no-input timeout, complete default answer, and answer before deadline for
  each question type; no prompt/answer formatting regressions.
- Consecutive questions, mixed timed/untimed input, repeated timeouts then answer,
  and no stale reader consuming a later answer.
- Pipe and canonical TTY behavior, LF/CRLF, EOF with/without trailing newline,
  delayed UTF-8 fragments, and timeout during partial input.
- Explicit cleanup/cancellation without abandoned input workers or changing the
  terminal into raw mode as a hidden side effect.
- Public wait-human handler timeout/default routing and existing interviewer
  contracts, followed by full sentinel, standalone bundle and CLI verification.

ATTR-HUM-02 remains missing. This is a discovered dependency, not completion of
the console feature or a blocker for unrelated Attractor requirements. Continue
artifact discoverability while the runtime capability is being resolved.

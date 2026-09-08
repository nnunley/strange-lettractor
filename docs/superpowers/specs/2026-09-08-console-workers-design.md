# Combined console and external workers

Status: proposed design, not implemented. User requested an agent/workflow
console and let-go evaluation in the same console with different escaping.
This extends the project beyond the StrongDM conformance baseline; it does not
replace or satisfy outstanding Attractor requirements by itself.

## Delivery choice

Start with a streaming console over existing agent/workflow controls; add the
full-screen TUI over the same control layer. A full TUI first would require
editing, terminal restoration, resizing and stream redraw to land together.
Separate agent and language REPL applications would be simpler but contradict
the requested single-console experience. A browser interface is not needed.

Proposed entry point: `attractor console`. Agent identity, run identity and worker
kind accompany streamed output, tool activity, errors and completion. Selection
changes do not relabel events already in flight. Let-go owns orchestration,
terminal rendering, subprocesses and internal `.edn` records.

## Input contract

- Unprefixed input is a message to the selected agent.
- `/help`, `/agents`, `/focus`, `/run`, `/cancel`, `/quit` are control commands.
- `: <forms>` explicitly submits let-go code to a persistent console namespace;
  `:keyword` without the space remains ordinary agent text.
- A leading backslash quotes command/eval-looking input as literal agent text.
- `:{` on its own line enters multiline eval; `:}` on its own line submits it.
  Ctrl-C discards an unsubmitted buffer. Within the buffer, `\:}` appends a
  literal `:}` line instead of submitting. Nested `:{` is ordinary code text.
  These are console framing delimiters, not Clojure syntax. Preserve the native
  Clojure reader rather than inventing a restricted EDN language or second parser.
- Prefixes apply at column zero. Unknown slash commands fail explicitly rather
  than becoming prompts. Echo the selected route before execution.

Evaluation binds the selected session/run at submission time, exposes useful
inspection/control helpers, and keeps language values distinct from agent text.
Code evaluation is trusted local code with the user's authority, not a sandbox.
Never evaluate model output, restored transcripts or loaded `.edn` records.
One eval at a time; errors are rendered without terminating the console. Do not
promise hard interruption of arbitrary native calls without runtime evidence.

## Workers and usage

Use Qwen through the existing unified-model path for bounded discovery and
implementation. Add Claude Code as an owned external coding-agent worker;
continue Codex app-server work as another external worker. A Claude Code worker
is not the Anthropic model adapter: it owns its own tool loop and CLI protocol.
Normalize worker lifecycle/events at the control boundary, not by pretending
every external agent is a single LLM completion call.

Worker configuration explicitly selects backend, model where applicable,
working directory, capabilities and limits. Fail visibly when a worker is
unavailable or unauthenticated; do not silently fall back to a different paid
provider. Do not assume quota or billing identity from executable presence.
Qwen availability and actual worker authentication need live verification.

To conserve Codex availability, prefer external Qwen/Claude tasks with bounded
inputs, named file ownership and mechanical acceptance commands. Reserve Codex
work for integration and difficult review, rather than adding Codex subagents
as a usage-distribution strategy. No automatic commits, pushes, permission
bypasses or new credentials are implied by worker selection.

## Runtime and validation

Use [tiny-tui](https://github.com/abogoyavlensky/tiny-tui) as the preferred TUI
foundation, per the user's suggestion. It is implemented for let-go, integrates
through `lgx.edn`, and provides input, selection, layout/style, terminal cleanup
and scripted-input/headless test seams. Observed tag `v0.1.3` resolves to
`3d2aeaa68e4647187c10cbbcba7df881b81b9a6c`; validate and pin the chosen dependency
before integration rather than following an unpinned branch. Compatibility
evidence: all 202 upstream tests / 410 assertions pass with the local let-go;
the same 202/410 pass from a standalone bundle launched outside the checkout.
The upstream fixed `/tmp` test fixture was relocated inside our uniquely
allocated directory for repeated/bundled runs. This proves current headless
library/bundle compatibility, not native-Go AOT parity or the combined console.
Native PTY smoke: the upstream counter renders, arrow-up changes count to 1,
and `q` exits with `Final count: 1`, cursor/main-screen restoration sequences and
process exit 0. A strict `stty -g` equality check initially failed only because
macOS sets `PENDIN` (`0x20000000`) when returning from raw mode. A no-library
`stty raw; stty <saved-state>` control produces the identical change, while
ordinary shell input does not. This is not evidence of a let-go/library bug;
all other observed terminal fields match. Resize/Ctrl-C/exception native cases
and combined input/stream behavior still need their own acceptance tests.

The inspected `tiny-tui.core/run` loop waits for keyboard messages and treats
Ctrl-C as program exit before calling the app update function. Our streaming
console needs an event source that merges worker events with keys, and routes
Ctrl-C according to input/eval/run state. Reuse the library's widgets/rendering
and terminal lifecycle with a small app-owned adapter; do not assume the stock
blocking loop already provides multi-agent streaming or multiline REPL behavior.
No upstream library edits or replacement toolkit are selected at this stage.

Reuse let-go REPL facilities after capability checks. The TUI owns
one input source and restores terminal state on exit/error. Do not put a future
timeout around blocking `read-line`, or mix competing buffered/key readers.
Noninteractive transcript tests exercise the same command dispatcher and control
layer; native PTY tests must cover EOF, Ctrl-C, resize and terminal restoration.

Mechanical tests must prove prefix/literal/multiline routing; namespace
persistence; no implicit evaluation; session selection captured at submission;
interleaved worker event identity; worker failure/cancel/exit; and regression-free
workflow launch and pinned recovery. CLI-worker protocol fixtures must be let-go.
Live Qwen and Claude trials are separate evidence from deterministic fixtures.

## External design review

An actual Claude Code read-only print/stream-json trial returned a critique with
exit 0 after network approval; the initial sandboxed attempt failed DNS and
terminated. This proves this bounded CLI invocation worked, not a completed
connector, subscription accounting, bidirectional protocol or cancellation.

Accepted findings: exact input routing rules, visibly identified output with
per-session line buffering, and cancellation/control processing independent of
blocked input. Keep selection and identity in the control API from the start;
Claude's suggestion to omit selection entirely is only appropriate to a first
single-worker UI milestone, not a reason to remove the requested multi-worker
design. Bind selected objects at submission, rather than allowing a later focus
change to retarget an in-flight eval. Loading EDN remains data reading, not
implicit execution; an explicit human eval can of course execute user code.

## Sequence

1. Finish and review the isolated subagent lifecycle ownership fix.
2. Review this design and pin the console command/evaluation contract.
3. Build the line console plus let-go eval and Qwen worker selection.
4. Add and exercise the owned Claude Code worker with permission/error handling.
5. Add full-screen presentation, retaining the transcript frontend for tests and
   non-TTY use; continue Codex app-server integration without claiming existing
   framing work is a complete connector.

The first useful milestone is a single console that can message Qwen, inspect
the session through explicit let-go evaluation, stream identified events, and
cancel/close cleanly. Full TUI and multi-worker parity remain subsequent work.

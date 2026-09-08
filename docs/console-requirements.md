# Console extension requirements and evidence

User-requested addition to StrongDM Attractor conformance. All items pending
unless concrete evidence below says otherwise. No conformance story is removed.

| Story | Acceptance / proof obligation | Evidence seam |
|---|---|---|
| CONSOLE-INPUT-01 | Prefix routing, literal escapes, multiline framing, discard/EOF, immutable submission selection; never evaluate during routing | Public reducer transcript tests, SCN-CONSOLE-INPUT |
| CONSOLE-EVAL-01 | Persistent native namespace; values/errors rendered; selected session/run bound at submission; explicit human input only | Real evaluator integration, including error then successful next eval |
| CONSOLE-CONTROL-01 | Agent text and workflow commands share console; focus and events preserve session/run identity | Console transcript through actual controller with deterministic provider |
| CONSOLE-INPUT-02 | One owned input source, concurrent stream redraw, cancellation, EOF and terminal restoration | Native PTY including Ctrl-C, resize, exception, shutdown |
| CONSOLE-WORKER-01 | Qwen invoked through Attractor; bounded live implementer trial and mechanical acceptance | Framework live run against llama.cpp, not a direct CLI substitute |
| CONSOLE-WORKER-02 | Owned Claude Code subprocess, streaming events, explicit permissions, failure/cancel/exit; no silent fallback | Let-go protocol fixture plus separately recorded live framework trial |
| CONSOLE-WORKER-03 | Codex app-server orchestration and interleaved identified worker events | Protocol integration and live framework trial |
| CONSOLE-TUI-01 | tiny-tui full-screen presentation using same dispatcher as line console | Headless integration plus native PTY |
| CONSOLE-HUB-01 | RPC hub owns framework sessions, workers and evaluation; console is a client; disconnect does not implicitly cancel work | Separate-process client/hub lifecycle tests, explicit cancel and reconnect/event subscription evidence |

## SCN-CONSOLE-INPUT

Status: implemented, focused/full/bundle verified; paired final audit clean.
Story: CONSOLE-INPUT-01. Seam: pure public reducer; this is
not evidence of a working CLI, evaluation, or streaming UI.

Feed line/interrupt/EOF events and supplied selection maps to
`attractor.console.input/accept`. Assert exact actions and payload preservation,
including code-looking literals, unknown commands, multiline character literals,
delimiter near misses, draft-only cancellation and selection changes before/after
submission. No models, shell processes or reader evaluation belong at this seam.

Command: `/Users/ndn/development/let-go/lg -source-paths src:test dev/console_input_tests.lg run`.

## Baseline

Before console code: full local-lg `lgx test` completed with 679 tests,
6613 assertions and zero failures (session 71405, exit 0). This proves the
existing baseline only. tiny-tui compatibility evidence is in the design doc;
it does not satisfy CONSOLE-TUI-01.

## Current component evidence

- RED: missing namespace exit 1, then minimal stub 6 tests / 25 pass / 63 fail.
- Focused public reducer: 7 tests / 92 assertions / zero failures, independently
  rerun by main and reviewer. Scope/spec reviews approved by Codex and actual
  external Claude Code CLI (not an Attractor-managed Claude worker).
- Full suite: 686 tests / 6705 assertions / zero failures, exit 0. Exact baseline
  delta is the new 7 tests / 92 assertions; no existing source was modified.
- Standalone focused bundle outside checkout: 7/92/0, exit 0. CLI build/help exit 0.
- No full console command, RPC hub, terminal integration or worker connector is
  delivered by these results. Native-Go AOT remains separate from bundling.

Frontend adapter follow-ups: keep reducer state separate from UI/controller state;
deliver logical lines individually, not pasted multiline strings in one line
event. The current exact escaped-close rule cannot encode a literal backslash
followed by a closing delimiter as a standalone line; revisit framing ergonomics
before declaring unrestricted multiline REPL input complete.

Review adjudication: slash commands are the current frontend vocabulary, not an
exhaustive hub operation registry; revisit capability discovery with RPC design.
Interrupt/EOF intents deliberately differ from typed commands so the client can
apply presentation/disconnect policy before RPC dispatch. Draft discard is visible
as a state transition, not a worker cancellation event. Explicit human eval is
trusted native code; the reader contract is not narrowed by a reviewer suggestion
to disable native evaluation features. The safety boundary is never evaluating
model output or loaded data implicitly. The dev runner intentionally follows the
repository's explicit `run` argument convention; use the documented command.

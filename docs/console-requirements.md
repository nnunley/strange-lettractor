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

CONSOLE-HUB-01A is the implemented agent-ownership component of CONSOLE-HUB-01,
specified in `docs/hub-session-plan.md`. Its public in-process integration scenario
SCN-HUB-AGENT-OWNERSHIP proves actual agent ownership, scoped client detach,
cancel/shutdown and bounded event history. It does not satisfy the parent story's
separate-process RPC or workflow/evaluation obligations.

## SCN-HUB-AGENT-OWNERSHIP

The in-process `attractor.hub` owns actual agent sessions and native scoped turn
workers. Public requests cover open/list/submit/cancel, client attach/detach and
joined shutdown; bounded event history uses explicit replay cursors. Event origin
is captured at emission and per queued child input, not callback delivery.

Focused native and outside-checkout bundle: 20 tests / 149 assertions, no failures.
Existing affected lifecycle checks: 166/1044/0. Full default suite: 719/6926/0.
Build/help pass. A live tool-free Qwen turn through hub -> agent -> unified client
-> llama.cpp returned `hub connected`, with 7 retained events and 2 text deltas
after detach and attachment of a new observer. This is not a separate-process RPC
or terminal client test.

Actual Claude implemented the bounded origin change through the published
let-go connector. Main stabilized the original failing fixture, strengthened
queued-nil and active/idle-close evidence, and ran the commands. A separate
read-only Claude review approved the agent/test changes; its hub read window
missed the mapping, which main inspected directly. No full TUI/hub story closure.

## SCN-CLAUDE-WORKER

CONSOLE-WORKER-02's standalone/DOT worker component is public as `84c3b7a`.
Native subprocess tests pass 7/40; CLI plus existing CLI tests pass 12/89. Both
compiled direct and real DOT LICENSE trials succeeded through the connector.
See [worker interface and permissions](claude-worker.md). Hub worker attachment
and interleaved console rendering remain pending.

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

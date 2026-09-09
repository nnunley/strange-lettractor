# Console extension requirements and evidence

User-requested addition to StrongDM Attractor conformance. All items pending
unless concrete evidence below says otherwise. No conformance story is removed.

| Story | Acceptance / proof obligation | Evidence seam |
|---|---|---|
| CONSOLE-INPUT-01 | Prefix routing, literal escapes, multiline framing, discard/EOF, immutable submission selection; never evaluate during routing | Public reducer transcript tests, SCN-CONSOLE-INPUT |
| CONSOLE-EVAL-01 | Persistent native namespace; values/errors rendered; selected session/run bound at submission; explicit human input only | Verified in-process: SCN-HUB-CONSOLE-OPS and SCN-CONSOLE-CONTROL |
| CONSOLE-CONTROL-01 | Agent text and workflow commands share console; focus and events preserve session/run identity | Verified: SCN-CONSOLE-CONTROL transcript through the real hub with the fixture provider |
| CONSOLE-INPUT-02 | One owned input source, concurrent stream redraw, cancellation, EOF and terminal restoration | Partial: native PTY covers Ctrl-C, EOF and restoration (SCN-CONSOLE-TUI); resize and exception paths pending |
| CONSOLE-WORKER-01 | Qwen invoked through Attractor; bounded live implementer trial and mechanical acceptance | Partial: live Qwen conversation turn through the console hub (SCN-CONSOLE-LINE); bounded implementer trial pending |
| CONSOLE-WORKER-02 | Owned Claude Code subprocess, streaming events, explicit permissions, failure/cancel/exit; no silent fallback | Let-go protocol fixture plus separately recorded live framework trial |
| CONSOLE-WORKER-03 | Codex app-server orchestration and interleaved identified worker events | Verified: transport 4/41 and worker 3/15 against the let-go fake child, `/agent codex` through the hub (SCN-CONSOLE-CONTROL), one live turn via `bin/attractor agent codex` |
| CONSOLE-TUI-01 | tiny-tui full-screen presentation using same dispatcher as line console | Verified: SCN-CONSOLE-TUI headless plus native PTY |
| CONSOLE-HUB-01 | RPC hub owns framework sessions, workers and evaluation; console is a client; disconnect does not implicitly cancel work | Partial: in-process hub owns sessions, evaluation, workflows and workers and client detach leaves work running (SCN-HUB-CONSOLE-OPS, SCN-CONSOLE-CONTROL); separate-process RPC and reconnect/replay pending |

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

## SCN-HUB-CONSOLE-OPS

Story: CONSOLE-EVAL-01, CONSOLE-HUB-01 (in-process operations component).
`attractor.hub` serves `:eval/submit` (persistent `attractor.console.user`
namespace with interned `hub`, `request!`, `events-since`, `*session*`,
`*run*`; one evaluation at a time, busy rejected, printed output captured,
errors rendered), `:workflow/run|cancel|list` (hub-owned pipeline runs with
cooperative cancellation) and `:agent/run|cancel|list` (owned external
agent jobs through the registered connectors). Every source shares the
bounded event log. Evidence 2026-09-08: `dev/hub_console_ops_tests.lg` 6 tests /
33 assertions with the fixture provider, a mock DOT workflow and the let-go
worker fixture, including busy, cancel-leaves-hub-alive and failure paths.
Requires the local runtime's context-aware `eval` (nooga/let-go#833).

## SCN-CONSOLE-CONTROL and SCN-CONSOLE-LINE

Stories: CONSOLE-CONTROL-01, CONSOLE-EVAL-01 (client side), CONSOLE-INPUT-02
(line frontend part). `attractor.console.session` is the frontend-independent
dispatcher (attachment, focus, reducer state, rendering of identified events);
`attractor.console.line` is the streaming line frontend; `attractor console`
starts an in-process hub with the run/resume model, worker and interviewer
configuration. Evidence: `dev/console_session_tests.lg` 4 / 39 (agent text,
eval values/errors/multiline/selection binding, /run + /claude + /agents +
/focus + /cancel + escapes, interrupt routing, quit detaches without stopping
the hub); `dev/console_line_tests.lg` 2 / 12 (scripted transcript, EOF).
Live: a Qwen turn through `attractor console --model qwen3.8-27b --provider
openai-compat` (the provider was then still named `ollama`) against llama.cpp returned `console connected` and `turn complete`.

## SCN-CONSOLE-TUI

Story: CONSOLE-TUI-01, CONSOLE-INPUT-02 (TUI part). `attractor.console.tui`
runs the same dispatcher on tiny-tui (pinned `v0.1.3`, `3d2aeaa6`) with an
app-owned reader merging keys and hub-event ticks; Ctrl-C discards a draft,
cancels busy focused work, or quits when idle. Evidence:
`dev/console_tui_tests.lg` 2 / 13 headless (scripted keys, captured frames);
`dev/console_pty_check.lg` 2 / 11 drives the built CLI under a real
pseudo-terminal through script(1): alternate screen entered and restored,
status line, echoed input, mock reply, evaluation, exit 0, and the line
frontend quitting on EOF. Resize and exception-restoration cases are not yet
covered natively.

## Review of the console milestone

An independent read-only review through `bin/attractor claude` reported 18
findings. Fixed with regression tests: workflow/worker entries registered
after launch (fast failures stayed "running"); three independent focus slots
(now one focus plus a remembered agent session, so `/cancel` targets what
`/focus` selected); `/run` without `--auto-approve` building a stdin-reading
interviewer under the frontend (refused until questions arrive as hub events);
eval namespace and `in-ns` shared across hubs in one process (per-hub
namespaces, process-wide eval lock); unbounded text buffers (64 KiB cap,
dropped on terminal events); `drain!` throwing on cursor expiry (resyncs and
reports dropped events); Ctrl-C throwing when the hub cannot answer; the
"final drain" after detach being a no-op; boolean flags consuming values;
`/quit` help promising survival while the CLI stops its in-process hub (now
warns and propagates a real exit code); console model resolution diverging
from run/resume; `:eval_start` sequenced after a fast result; `#uuid` ids;
bare lines for empty text; fixture-only `:scenario` accepted from any request.
Recorded, not fixed: finished sessions/runs/agent jobs are never pruned; reader
futures stay parked after quit (masked by process exit in the CLI).

## SCN-HUMAN-GATES (2026-09-08)

Human gates no longer read stdin under the console. The hub publishes each
`wait.human` question as a `:source :question` event with its options and
`timeout_seconds`; the console renders `[run id] ? text` with `[key] label`
lines and answers through `/answer <key or text>` (focused run first, or the
only waiting run). `/list` marks runs "waiting for an answer"; `--auto-approve`
now merely selects the first option. Evidence: `dev/hub_console_ops_tests.lg`
12 tests / 68 assertions and `dev/console_session_tests.lg` 7 / 73. This
closes the console's "cannot answer human gates" limitation and proves
ATTR-HUM-02 at the hub seam; the standalone stdin interviewer is unchanged.

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

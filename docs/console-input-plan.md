# Console input routing implementation plan

Status: implementation, tests, paired quality reviews and final audit verified.
This is a component of the user-requested console extension, not full delivery.

**Goal:** One mechanically tested framing contract for agent messages, commands
and explicit let-go evaluation in both console presentations.

**Architecture:** `attractor.console.input/accept` is a pure reducer returning
`{:state ... :action ...}`. It never invokes a reader, evaluator, agent or shell.
The caller supplies a selection map; completed actions capture it as `:selection`.
Multiline evaluation captures selection when the closing delimiter submits it,
just like single-line evaluation. The later dispatcher must validate that the
captured session is still available. A focus change after submission must not
retarget the action; a focus change while editing affects the eventual selection.

**Tech stack:** local let-go >=1.12.2; clojure.test. No new dependencies here.
tiny-tui remains the presentation library for the later TUI.

## Chunk 1: framing contract

Files: create `src/attractor/console/input.lg`,
`test/attractor/console_input_test.lg`, `dev/console_input_tests.lg`.

- [x] Write failing tests for plain text, column-zero prefixes, escaped literals,
  known/unknown commands, and blank input.
- [x] Run `/Users/ndn/development/let-go/lg -source-paths src:test dev/console_input_tests.lg run`;
  verify missing implementation, then assertion failures against a minimal stub.
- [x] Implement `accept [state event selection]`; events are `{:type :line :text s}`,
  `{:type :interrupt}`, or `{:type :eof}`. Initial state is `{}`. Actions use
  `:type :agent/:command/:eval/:error/:cancel/:quit` with appropriate `:text`,
  `:command`, `:args`, or `:message`. Idle blank input is a no-op. Preserve all
  nonblank agent/eval payload whitespace. Only ASCII space after `:` enters eval.
  A leading backslash strips exactly one character and forces agent text;
  blank-after-strip is a no-op. Recognize slash command names
  separated by whitespace; preserve arguments after leading separator whitespace.
  Known commands are help, agents, focus, run, cancel, quit. All six emit command
  actions (including quit); EOF alone emits a quit action. Unknown slash commands
  emit errors. Single-line `: ` emits an eval action with empty text.
- [x] Add failing multiline tests; implement exact-line `:{`/`:}` framing,
  newline joining, escaped close, nested open as text, submission-time selection
  capture, interrupt discard, and EOF discard plus quit. Empty multiline
  submission emits explicit eval with empty text. Buffer interrupt clears state
  with nil action: it must not cancel a running worker. Idle interrupt emits cancel
  with current selection. Unknown event types emit errors preserving state.
  EOF always clears state and emits quit.
- [x] Prove purity with code-looking input and Unicode payload preservation.
  Include ordinary backslashes, slash commands and eval prefixes inside multiline
  buffers as verbatim text; delimiter trailing space/CR must prevent framing.
- [x] Run focused tests, full regression suite and standalone focused bundle
  outside checkout. Review code and evidence before commit/push.
  Full suite: `env PATH=/Users/ndn/development/let-go:/opt/homebrew/bin:/usr/local/go/bin:/usr/bin:/bin:/usr/sbin:/sbin /Users/ndn/.local/share/mise/installs/github-abogoyavlensky-lgx/0.1.0-rc2/lgx test`.

## Remaining delivery (not satisfied by reducer tests)

- Persistent native eval namespace and captured session bindings; no implicit eval.
- Agent/workflow controls and identified streaming events.
- Owned input lifecycle, cancellation and EOF with native terminal evidence.
- Qwen live trial, Claude Code worker, Codex app-server, full-screen tiny-tui adapter.
- Original StrongDM requirements stay open in the existing iteration backlog.

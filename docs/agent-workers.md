# Agent Workers — Codex, Claude, Qwen

## Codex App-Server Integration

# Codex app-server integration

Status (2026-09-08): transport, one-turn agent and registry entry are
implemented and tested against the let-go fake child, and one live turn ran
against the installed `codex-cli 0.153.4`: `bin/attractor agent codex`
with a read-only sandbox returned "codex connected" (37 protocol
records, 3 text deltas, one completed event, exit 0). This backend uses
Attractor's existing orchestration rather than a shared cross-provider
conversation or a second workflow engine.

## Implementation

- `attractor.codex.transport`: `open!`/`send!`/`close!`. The child runs under
  a shell that records its PID and exit status; stdin is a FIFO held open for
  writing, stdout/stderr are files read incrementally through the bounded
  framing decoder. This avoids the byte-array (#813) and boxed pointer (#814)
  interop limits without a Go change. Server requests (approvals, permissions,
  tool calls) are answered with a JSON-RPC error: the agent never grants
  authority on the user's behalf. Close gives the child `:shutdown-ms`, then
  TERM and KILL by exact PID; `close!` is idempotent.
- `attractor.agents.codex/run!`: initialize → initialized → `thread/start`
  (`cwd`, `approvalPolicy`, `sandbox` as the kebab-case `SandboxMode`, optional
  `model`) → `turn/start` with one text input; streams `item/agentMessage/delta`
  as `:text_delta` events and completes on `turn/completed`. `turn/interrupt`
  is sent on cancellation. Options: `--sandbox read-only|workspace-write|
  danger-full-access`, `--approval-policy never|on-request|untrusted`.
- Selected as `bin/attractor agent codex`, `--agent codex` (DOT runs) or
  `/agent codex` (console).

Evidence: `test/runner.lg attractor.codex-transport-test` 4 tests / 41 assertions (duplex
exchange, split/coalesced/delayed frames, malformed/partial-EOF/stderr-flood
failures reported once, ignore-EOF child killed by exact PID);
`test/runner.lg attractor.codex-agent-test` 3 / 15 (completed turn with deltas, failed turn,
refused approval, invalid options, interrupt on cancel). The live server's
rejection of an object-shaped `sandbox` during development is what fixed the
wire format (`SandboxMode` strings, not `SandboxPolicy` objects).

- [Design](superpowers/specs/2026-09-06-codex-app-server-design.md)
- [Transport implementation plan](superpowers/plans/2026-09-06-codex-app-server-transport.md)

## Installed protocol inspection (2026-09-07)

`codex --version` reported `codex-cli 0.153.4`. The following command generated
schemas successfully into a fresh temporary directory:

```sh
codex app-server generate-json-schema --out <temporary-directory>
```

Inspected `v1/InitializeParams.json`, `v1/InitializeResponse.json`,
`RequestId.json`, and the client notification/request definitions:

- Initialize parameters require `clientInfo`, whose `name` and `version` are
  required strings; `title` is optional. Capabilities are optional.
- Initialize results require `codexHome`, `platformFamily`, `platformOs`, and
  `userAgent`. Validate the result but do not publish the home path in evidence.
- Request IDs support strings and signed 64-bit integers. Allocate integer
  client IDs; preserve server IDs without coercion.
- Send `initialized` after a successful initialize response. Readiness is not
  established by process launch alone.
- `codex app-server --stdio` is supported by this installed version.

These are local schema observations, not a live handshake result. No model turn
or authentication request was made. The generated schema bundle is not tracked.
See the [official protocol documentation](https://learn.chatgpt.com/docs/app-server)
for lifecycle context; implementation must verify the installed wire behavior.

## Evidence boundary

The local let-go binary successfully sent and received a line through a live
`/bin/cat` child while stdin remained open. This establishes basic duplex process
I/O through existing interop; it does not establish resource cleanup under
failure, bounded framing, app-server readiness, AOT compatibility, or agent
integration. Those are explicit mechanical gates in the transport plan.

The initial planning checkpoint included no production changes or model trials.
The framing implementation and its evidence are described below; no live
Qwen/Codex model trial has been performed for this connector.

## Runtime findings (2026-09-07)

- [Mutable byte-array interop](let-go-runtime-issues.md), upstream
  [#813](https://github.com/nooga/let-go/issues/813): Go reads mutate a copied
  slice rather than the caller's array. Buffered single-byte reads were verified
  as a possible bounded-framing workaround.
- [Boxed pointer field lookup](let-go-runtime-issues.md), upstream
  [#814](https://github.com/nooga/let-go/issues/814): accessing the owned
  `exec.Cmd.Process` field fails before pointer dereference. Exact-child forced
  termination remains unverified; stdin closure alone is not sufficient.

Neither finding changes the orchestration design. The runtime checkout has not
been changed. Use native let-go/Go facilities,
not JVM-shaped replacements; retain the shutdown gate while resolving #814.

## Deterministic fixture evidence

Run from the Codex worktree root:

```sh
/Users/ndn/development/let-go/lg test/probes/codex_fixture_smoke.lg
/Users/ndn/development/let-go/lg -source-paths src:test -e '(require (quote harness.tests) (quote attractor.codex-transport-test)) (harness.tests/run-and-exit! (quote attractor.codex-transport-test))'
```

On 2026-09-07 the smoke harness exited zero: normal, split, coalesced, delayed,
stderr-flood, malformed, partial-EOF and ignore-EOF modes behaved as specified.
The live two-request probe kept stdin open and independently checked fixture
PID liveness before close and disappearance afterward. Every fixture has a
finite safety lifetime; the ignore-EOF check observes that deadline, not a
production transport kill.

The transport contract intentionally exited 1: one test, one missing-namespace
failure, zero errors. The feature branch is therefore not suite-green and must
not merge to main as a completed connector. The fixture is tested scaffolding;
production transport, bounded shutdown and RPC initialization evidence
remain pending. The existing main branch is unchanged.

## Bounded framing implementation

`attractor.codex.framing` incrementally accepts byte chunks and returns explicit
`{:raw-json ... :message ...}` frame envelopes. It bounds payload bytes, validates
UTF-8 before parsing, rejects malformed/non-object JSON and partial EOF, and
latches failures. If any frame in a feed is invalid the entire feed fails;
callers must close the connection rather than retry or assume partial delivery.

Focused direct tests passed 128 assertions (one test), zero failures/errors.
A standalone bundle containing both the decoder and its test ran outside the
repository and passed the same 128 assertions. This tests packaged bytecode,
not native Go AOT lowering or the unimplemented process transport.

The full feature-branch suite completed with 569 tests, 4,839 assertions and one
failure. The missing-transport contract remains deliberately failing; this is
not a green release checkpoint.

```sh
/Users/ndn/development/let-go/lg -source-paths src:test test/probes/codex_framing_check.lg run
/Users/ndn/development/let-go/lg -source-paths src:test -b <temporary-output>/framing-check test/probes/codex_framing_check.lg
# From outside the repository:
<temporary-output>/framing-check run
```

The entrypoint explicitly requires the decoder so bundling includes it; a
runtime-only require from inside the test does not establish that dependency.

Parsed numbers still inherit [JSON precision issue #815](let-go-runtime-issues.md).
The exact raw JSON survives EDN serialization, but lossless RPC correlation is
not implemented or proven. No pending process-lifecycle requirement is waived
by passing framing tests.

---

## Claude Worker

# Claude Worker — Agent & Implementation Plan

## Claude Agent Reference

# Claude Code agent

Strange Lettractor launches Claude Code as an owned external agent. Claude runs
its own tool loop; this is separate from the Anthropic unified-LLM adapter.
The connector is implemented in let-go and does not depend on the unfinished hub
or TUI.

Build with your local let-go, then use a prompt file:

```sh
lgx build
bin/attractor agent claude --prompt-file examples/claude-smoke.md --cwd . --model sonnet
```

Output is a stream of EDN event maps identifying the job and Claude session.
Claude's JSON-lines protocol stays inside the connector. Token deltas are distinct
from complete assistant/result records; consumers must not concatenate all three.
See Claude's [programmatic streaming protocol](https://code.claude.com/docs/en/headless)
for the external message format.
The command exits nonzero for failed, malformed, missing-result, timed-out or
cancelled work. Default timeout is 120000ms; set `--timeout-ms` explicitly for
longer tasks.

Default access is `--tools Read --permission-mode plan`. To authorize editing:

```sh
bin/attractor agent claude --prompt-file task.md --cwd . --tools Read,Edit,Write --permission-mode acceptEdits
```

This is explicit tool authority, not a sandbox. There is no permission-bypass flag.
Permissions needing interaction are denied, not silently approved. Claude's safe
mode disables customization/hooks/MCP for these jobs; normal CLI authentication
is retained. Authenticate using Claude's own CLI; the connector does not copy
credentials or choose a replacement provider. CLI availability does not prove
subscription billing or remaining quota.

## Console use

`attractor console` dispatches the same connector as a hub-owned agent job:
`/agent claude <prompt> [--cwd d] [--model m] [--tools a,b] [--permission-mode p]`
(`/alias claude agent claude` if you want the short form). Job defaults come
from `--agent-cwd`, `--agent-model`, `--agent-tools`, `--agent-permission-mode`
and `--agent-timeout-ms` on the console command. Events render as
`[claude <id>]` lines; `/cancel` with the job focused requests cooperative
cancellation; `/list` shows running and finished jobs. See `docs/console-requirements.md` (SCN-CONSOLE-CONTROL).

Known strictness limit (2026-09-08): a long review run (34 turns) returned a
valid successful `result`, after which the CLI emitted one more record; the
connector reports `:claude-protocol` "record after its terminal result" and
exits 1 although the result text is intact in the event stream. Follow-up:
tolerate records after a valid terminal result (surface them, keep exit 0).

## Workflow and library use

```sh
bin/attractor run examples/claude-smoke.dot --agent claude --model sonnet --auto-approve --cwd .
```

`run` and `resume` accept `--agent claude` plus the same options. This
explicit selection never falls back to mock or an API-key model adapter.
`--mock` cannot be combined with it. `--auto-approve` concerns workflow human
gates; it does not grant Claude additional tool permissions.

The library entry points are `attractor.agents.claude/run!`,
`attractor.agents.registry/run!` (by agent name) and
`attractor.agents.backend/make-backend` (any agent as a codergen backend). Options include `:prompt`,
`:working_dir`, `:model`, `:tools`, `:permission_mode`, `:timeout_ms`,
`:cancelled?`, and `:on_event`. `run!` returns the final text/result or throws a
tagged failure only after its owned command has been joined.

This initial connector is one-shot. Full-fidelity Claude session reuse and
interception of Claude's internal tools by Attractor tool hooks are rejected
explicitly, not silently emulated. Persistent bidirectional sessions and hub
attachment remain follow-up work.

## Process ownership

The local let-go runtime offers buffered `os/sh`, streaming `os/exec*`, and a
boxed `os/exec` command usable through Go interop. That low-level command is not
the framework's already-tested process-group cancellation/timeout contract.
The connector therefore reuses Attractor's existing execution environment for
process-group timeout/cancellation and private stdin, and reads bounded protocol
records incrementally from private output files while the process is running.
Shell glue is limited to quoted argv/redirection in that existing adapter.
Temporary files are removed only after joining; no Go/Python helper is added.

Deterministic tests use a real let-go child process, separately from a live
authenticated Claude trial:

```sh
export LGX_LG="$HOME/development/let-go/lg"
"$LGX_LG" -source-paths src:test test/runner.lg attractor.claude-agent-test
"$LGX_LG" -source-paths src:test test/runner.lg attractor.claude-cli-test
```

The fixture subprocess also uses `LGX_LG`; without it, it resolves `lg` from PATH,
which must likewise be version 1.12.2 or newer.

---

## Claude Worker Implementation Plan

# Claude worker implementation plan

User priority: deliver a reusable let-go Claude connector now; pause the unfinished
hub event-origin work. This executes the external-worker design already discussed,
without requiring the RPC hub or TUI to be complete.

## Contract

`attractor.workers.claude/run!` accepts a prompt, working directory, explicit tool
allowlist/mode, optional model, timeout, cancellation predicate and event callback.
It runs Claude Code's own tool loop, not an Anthropic model completion adapter.
Use installed `claude -p --output-format stream-json --verbose
--include-partial-messages --safe-mode --permission-prompts none`. Default tool
access is Read with plan mode; explicit edit mode may use acceptEdits and a named
allowlist, never bypass permissions or silently select another provider.
Auth stays with the installed Claude CLI; never read or copy credentials.

Let-go owns parsing, event identity, termination, and result validation. Reuse the
existing owned execution environment for process-group timeout/cancellation and
private stdin. Native os/exec offers a low-level boxed command, but os/sh buffers
output and os/exec* has no owned process handle/stdin binding. Reuse the proven
execution environment and stream stdout through a private temporary file
read incrementally by let-go while the owned command runs. Shell syntax is limited
to quoted argv/redirection through the existing execution adapter; no new shell
or Go orchestration implementation. Internal events/output use EDN; JSON lines
exist only at Claude's protocol boundary. Enforce record size/output bounds and
clean only exact owned temporary files after the process is joined.

Expose identified raw protocol records plus normalized text deltas and final
completion. Do not emit aggregate assistant/result text again as token deltas.
Require one valid terminal result and a successful process exit for success;
malformed/truncated streams, is_error, missing result and nonzero exit fail
explicitly. Callback failure must cancel and join the process before returning.

## Delivery steps

- [x] Add worker module `src/attractor/workers/claude.lg`, native subprocess
  fixture `test/fixtures/claude_worker.lg`, focused tests/runner. Red/green proves
  literal prompt transport, live events before exit, fragmented records, UTF-8,
  tool/result records, errors, cancellation and timeout with joined shutdown.
- [x] Add `attractor claude --prompt-file <file> [--cwd <dir>]` entry point,
  plus explicit `--worker claude` selection for existing DOT run/resume backend.
  Add CLI/backend tests. No missing API key means mock when Claude is selected.
- [x] Document short reusable commands and library use; run focused/impacted
  checks and a bounded real Claude prompt through this connector, not `lg -e`.
- [ ] Review the resulting implementation, build and verify CLI use; commit/push
  only connector files once verified. Preserve unfinished hub work separately.

The public hub origin regression remains intentionally failing and is not part of
this connector. Full default-suite reporting must disclose it rather than hide it.
This does not claim completed bidirectional persistent sessions, RPC or TUI.

## Evidence so far

Native subprocess suite: 7 tests / 40 assertions / zero failures. CLI plus
existing CLI regressions: 12 tests / 89 assertions / zero failures. Local let-go
build succeeds. A real `bin/attractor claude` invocation using the checked-in
LICENSE smoke prompt streamed identified protocol/text events and returned
`Apache-2.0` with successful terminal result and process exit 0. No ad hoc
`lg -e` or external shell review wrapper was used for that trial.

The actual compiled DOT smoke also succeeds through `--worker claude`: streamed
records contain a Read call targeting LICENSE, the saved response contains
Apache-2.0, and the checkpoint completes start/inspect/exit with the captured
workflow fingerprint. Connector correctness review found no blocking issues.

Final connector-only HEAD-plus-explicit-files publication candidate passes the
full default suite: 699 tests / 6777 assertions / zero failures, exit 0. Candidate
build/help also pass. The fixture interpreter honors nonblank LGX_LG, otherwise
PATH lg; use a supported runtime for both parent and child processes.
Do not interpret this as a green claim for the dirty console worktree's preserved
two-failure hub regression. Commit/push is the remaining delivery step.

---

---

## Qwen Worker

# Qwen Worker — Development Trials

## First Development Trial

# First Qwen development trial

The first real repository task used the existing let-go DOT engine and native
coding-agent loop with `qwen3.8-27b`, served by llama.cpp. The existing adapter
named `openai-compat` supplied its OpenAI-compatible Chat Completions transport; no
Ollama service was involved. Streaming was disabled for this trial.

Task: preserve a string `reasoning_content` field as normalized response
`:reasoning`, including the empty string; use nil for absent/non-string values.
Keep answer content, tool calls, usage, and raw data unchanged. This also restores
existing high-level generation/step reasoning propagation. Streaming reasoning
normalization was separate, unfinished work at the time of this trial. The later
[deterministic streaming fix](stream-schema-audits.md) is separate evidence,
not an additional autonomous Qwen development success.

## Outcome: assisted, not autonomous

Two bounded runs each reached 20 model requests. Qwen produced a regression test
and eventually proposed the correct production expression, but could not apply
the exact-match edit: its replacement searches repeatedly had incorrect leading
whitespace. Its first test also lacked a namespace and incorrectly expected a
nested response map. Review feedback helped it correct the test.

Neither DOT run passed its independent deterministic verification stage. Codex
then applied the two-line production change and supplemented Qwen's regression
coverage. Qwen's corrected test failed two assertions before that change.

The worker could modify only the adapter and its new test file, and could execute
only two fixed test commands. These tool allowlists are not an OS sandbox for
arbitrary code executed by tests. The known-good main checkout ran the workflow;
candidate changes lived in a separate `.worktrees` checkout. No private project
notes were included.

## Follow-up breadcrumbs

- Give workers explicit available paths and actionable permission errors.
- Improve exact-edit guidance and mismatch diagnostics without silently relaxing
  edit matching. The generic profile's edit description is currently minimal.
- Bound repeated unsuccessful calls and escalate with the actual tool evidence.
- Preserve a deterministic test gate: reaching the agent turn limit must not be
  interpreted as successful implementation merely because the handler returned.
- Align context budgeting with the server's active context (32,768 in this run),
  not the generic profile's larger default or the model's training maximum.

This trial does not establish unattended self-development readiness or broad
model-quality conclusions.

---

## Streaming Reasoning Fix

# OpenAI-compatible streaming reasoning

The local-model adapter (currently named `openai-compat`, also used with llama.cpp)
preserved `reasoning_content` in non-streaming replies but discarded the same
field in streaming deltas. A deterministic SSE probe containing `Think` followed
by answer text produced no reasoning events and a nil final reasoning value.

The compatible streaming adapter now emits reasoning start/delta/end events for
string values and accumulates exact reasoning into the final response. Empty
strings are retained; absent, null and non-string values are ignored, matching
the existing non-streaming normalization. Reasoning remains separate from visible
answer text and tool-call arguments. Errors suppress subsequent events and do
not fabricate a successful finish.

The reasoning-end event carries the final accumulated `:reasoning` value;
`:reasoning_delta` remains exclusive to incremental events. This follows the
typed-completion clause in pinned unified-LLM spec §3.14 without making a consumer
accumulate the same text twice.

## Mechanical evidence (2026-09-07)

- Missing-reasoning regression: 18 failed assertions, zero test errors before
  the implementation change.
- End-event value regression: three failed assertions before adding that field.
- Final focused suite: seven tests, 57 assertions, zero failures/errors.
- Combined LLM and focused contracts: 90 tests, 551 assertions, zero failures.
- A standalone bundled entrypoint explicitly requiring the adapter and focused
  test namespace passed the same seven tests / 57 assertions outside the repo.
  This verifies packaged bytecode, not native Go AOT lowering.
- Final worktree suite: 577 tests, 4,780 assertions, zero failures.

Run the focused suite with the local runtime:

```sh
/Users/ndn/development/let-go/lg -source-paths src:test -e '(require (quote harness.tests) (quote attractor.qwen-reasoning-test)) (harness.tests/run-and-exit! (quote attractor.qwen-reasoning-test))'
```

The tests exercise low-level streaming, a configured client, the stream
accumulator, and high-level response/text-stream access. They include mixed
reasoning/text/tool chunks, usage-only trailing chunks and errors followed by
late data. The native-provider LLM regression suite is retained unchanged.

## Scope and remaining evidence

This is a local normalization fix, not a live-model or subscription test. No
model calls were made and no let-go runtime changes were required. Native OpenAI
continues using Responses, Anthropic Messages and Gemini generateContent; this
does not replace those adapters with a compatibility API.

Reasoning-history replay and thinking-content-part representation are unchanged.
Repeated `[DONE]` handling and the corresponding accumulated-value fields on
other adapters' segment-end events remain separate streaming audit work. Do not
infer full streaming conformance or native-provider parity from this fix.

---

---

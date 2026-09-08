# Tool-call hooks

Attractor specification §9.7 defines shell hooks around LLM tool calls. Configure
them as graph defaults or node attributes:

```dot
digraph example {
  graph [tool_hooks.pre="true", tool_hooks.post="true"]
  start [shape=Mdiamond]
  work [prompt="Inspect the project"]
  no_pre_check [prompt="Summarize findings", tool_hooks.pre=""]
  exit [shape=Msquare]
  start -> work -> no_pre_check -> exit
}
```

Replace `true` with your hook commands. Each node overrides the corresponding
graph hook independently; an empty value disables that phase. Without a DOT
override, backend-configured defaults still apply. Hook commands use the agent's
execution environment and working directory, not the stage-log directory. Hooks
are executable workflow code, not a security sandbox.

Pre exit zero permits normal tool validation/execution. Nonzero exit, timeout,
execution error, unsupported stdin capability or a required audit-write failure
skips the tool and returns a bounded error to the model. Post observes every
attempted call, including errors and vetoes; its failure cannot replace the tool
result. Cancellation stops further work instead of acting as an ordinary veto.

## Hook input and audit output

Each hook receives these environment variables:

- `ATTRACTOR_HOOK_PHASE` (`pre` or `post`)
- `ATTRACTOR_NODE_ID`
- `ATTRACTOR_SESSION_ID`
- `ATTRACTOR_TOOL_CALL_ID`
- `ATTRACTOR_TOOL_NAME`

Stdin is external-protocol JSON with `phase`, `node_id`, `session_id`, `call_id`,
`tool_name`, and `arguments`. Arguments preserve their provider representation:
either an object or JSON text. Post also receives `result`, `is_error`, and
`skipped`. Result is the raw executor value, before model-output truncation.
Literal string keys are preserved, including empty and slash-containing keys.

Audit records are appended as EDN forms to `<stage-dir>/tool-hooks.edn`. They
contain call identity, phase, hook status and command result, including exit code
and output. Failures also produce hook diagnostic events. The append lock protects
concurrent writers in this process, not separate processes sharing one log file.
Standalone sessions without a stage directory emit events without a stage file.

## Session options

Standalone sessions and backend defaults accept:

```clojure
{:tool_hooks {:pre "true"
              :post "true"
              :timeout_ms 10000}}
```

`timeout_ms` defaults to 10000 and remains subject to the execution environment's
maximum command timeout. Standalone callers can also supply `:node_id` and an
existing `:stage_dir`. Custom environments need the optional five-argument
`:exec_command_stdin` operation `(command timeout cwd env input)` for hooks;
ordinary four-argument command execution is unchanged.

Reused sessions refresh hooks only when the next input is admitted. Descendants
share the refreshable context, but each tool call pins one context for its full
pre/tool/post sequence. A busy rejected caller cannot reconfigure or cancel the
active session. Pinned recovery resolves hooks from captured workflow attributes,
not subsequently edited DOT source.

For mechanical tests and explicit evidence boundaries, see
[the implementation plan](tool-hooks-plan.md).

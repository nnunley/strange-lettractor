# Tool-call hooks — scoped implementation plan

Status: scope approved; stdin transport component implemented and verified.
Agent hooks, workflow wiring and stage logging remain pending.

Source: snapshotted Attractor specification §9.7. This implements ATTR-HOOK-01
and SCN-TOOL-HOOKS within ITER-0007, not completion of that iteration.

## Contract

- Resolve `tool_hooks.pre` and `tool_hooks.post` independently, node attribute
  presence overriding graph defaults. An explicitly empty value disables that hook.
- The codergen handler passes resolved hooks and the current stage directory to
  the agent backend. Refresh this invocation context on every turn, including
  cached full-fidelity sessions. Standalone sessions may supply equivalent options.
- Run pre before each requested tool call, including invalid or unknown calls.
  Nonzero exit, timeout, or execution failure vetoes executor invocation and gives
  the model a bounded error result. Successful pre leaves normal validation intact.
- Run post after each attempted call, including tool errors and pre-veto results,
  so auditing sees every outcome. Post failure never replaces the tool result.
  Cancellation takes precedence: do not launch additional hooks or executors after
  cancellation, and retain existing owned-process cleanup guarantees.
- Hook commands execute through the session execution environment, with a bounded
  default timeout and its normal cwd, environment policy and cancellation handling.
  Do not introduce an unowned shell runner or handwritten Go fixture.
- Add optional `:exec_command_stdin` (command, timeout, cwd, env, input) without
  changing the existing four-argument operation. Local implementation writes input
  to an exclusively created private temporary file, invokes the existing owned
  command runner with safely quoted file redirection, then removes only that file
  and its empty private directory in `finally`. Raw input never enters argv or
  shell evaluation. Custom environments without this capability remain compatible
  when hooks are absent; configured hooks report unsupported capability (pre veto,
  post diagnostic), never silently bypass it. Test multi-MiB input and cleanup.
- Supply JSON on stdin: phase, node/session/call identity, tool name, arguments;
  post additionally receives the raw result and error/skipped flags. Supply compact
  identity metadata as `ATTRACTOR_HOOK_PHASE`, `ATTRACTOR_NODE_ID`,
  `ATTRACTOR_SESSION_ID`, `ATTRACTOR_TOOL_CALL_ID`, `ATTRACTOR_TOOL_NAME`.
  The exact names/schema are this implementation's contract, not specified upstream.
- Preserve literal JSON string keys and shell-sensitive payload text. Work around
  let-go #817 narrowly without lossy keyword conversion. Do not evaluate EDN.
- Append hook outcomes and failures as EDN forms to the stage's `tool-hooks.edn`.
  Keep model-facing tool output bounded and existing start/end events single and
  ordered. Explicitly test logging failures rather than silently swallowing them.
- Serialize stage-log appends under a shared writer lock so parallel descendants
  cannot interleave or lose EDN forms. If a configured pre-hook's required log
  cannot be persisted, veto the executor and emit a hook diagnostic event. A post
  log-write failure emits a diagnostic but preserves the original tool result.
  Standalone sessions without a stage directory use diagnostic events only.
- Descendant coding-agent sessions inherit hooks and stage context; refreshing a
  reused parent must not leave active descendants with stale invocation context.
  Inspect existing ownership/lifetime semantics before choosing the smallest fix.
- Share a refreshable invocation-context cell with descendants, but snapshot its
  immutable value once at each tool-call entry. That snapshot owns the full
  pre/executor/post sequence and log destination. Refresh affects subsequent calls
  only; prove this with a gated active-descendant call across a parent refresh.

## Tasks and mechanical evidence

1. Sentinel baseline passed: 609 tests / 5,679 assertions / zero failures, exit 0
   at c373771. Paired independent scope review of this contract.
2. TDD hook execution and serialization at the real session seam: success, veto,
   thrown/invalid/unknown tool, post failure, bounded errors, exact raw stdin,
   native shell quoting, timeout/cancellation and process cleanup.
3. TDD public workflow wiring: graph defaults, independent overrides, explicit
   disable, fidelity reuse and descendant inheritance. Read actual stage EDN logs
   and compare executor counts and next model requests; no model judge.
4. Paired spec then quality review. Run impacted scenarios and full sentinel suite
   with source frozen; build/bundle smoke checks (not native AOT conformance).
5. Record evidence and update requirement/scenario/corpus/progress artifacts, commit
   scoped files, fast-forward and push public main after verification.

RLM discovery, skill packaging, native HTTP cancellation and broad provider parity
remain separate work. Private `docs/notes.md` must remain untouched.

## Verified transport checkpoint

The optional local environment operation is implemented in `execution.lg`.
`execution_stdin_test.lg` proves SCN-TOOL-HOOKS-STDIN at the native command seam.
Inputs must be strings; existing four-argument execution callers are unchanged.
Cleanup exceptions include `:stdin_cleanup` with exact owned paths and failures.
When a command returned, cleanup failures also retain its complete `:command_result`.
When it threw, its message/category/data are retained, but exception identity is
not preserved if cleanup also fails. Both removal operations are attempted.

Mechanical evidence (local let-go compiler, candidate based on `c373771`):

- Initial RED: 2 passing assertions / 1 failing assertion (missing capability).
- Expanded cleanup/input RED: 51 passing / 2 failing assertions.
- Review regression RED: 62 passing / 7 failing assertions.
- Final focused: 7 tests / 74 assertions / zero failures.
- Impacted execution tests: 36 tests / 185 assertions / zero failures.
- Full default suite: 616 tests / 5,753 assertions / zero failures, exit 0.
- Standalone bundle executed outside the repository: 7 / 74 / zero failures.
- `lgx build` and built CLI `help`: exit 0. This is not native-Go AOT conformance.
- Paired independent scope, spec and quality reviews approved the component.

Focused reproduction:

```sh
/Users/ndn/development/let-go/lg -source-paths src:test dev/execution_stdin_tests.lg run
```

For standalone verification, compile that runner with `-b <output>` and execute
`<output> run`. The argument is required by the runner's command-line entry guard;
an argument-free zero exit with no counters is not test evidence.

The deliberately failing cleanup reproducers left two empty random temporary
directories whose paths were not retained. Their payloads were removed. No broad
cleanup was attempted; the regression now captures owned paths for exact cleanup.
This component creates no new upstream let-go issue and does not complete hooks.

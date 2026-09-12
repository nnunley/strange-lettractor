# Kilroy validation — 2026-09-11

Checked all six repository DOT files with upstream Kilroy commit
`b55fb0f2b3d5bfc603726d8ce5c5b89de81bfa2f`, built in
`/tmp/attractor-kilroy-validation`. Each file was checked with
`kilroy attractor validate --graph <file>` so the embedded model catalog
was loaded (Kilroy's batch path does not load that catalog).

| File | Errors | Warnings | Exit |
|---|---:|---:|---:|
| `examples/claude-smoke.dot` | 2 | 1 | 1 |
| `examples/composition-child.dot` | 2 | 1 | 1 |
| `examples/composition-parent.dot` | 2 | 1 | 1 |
| `examples/development-repl.dot` | 14 | 6 | 1 |
| `examples/hello.dot` | 2 | 3 | 1 |
| `examples/human_review.dot` | 4 | 3 | 1 |

Full command output is preserved in [kilroy-validation-results.json](kilroy-validation-results.json).
No graph was changed or executed during this check.

The development loop's errors are nine `all_conditional_edges` diagnostics
and five `terminal_condition_edge` diagnostics. Its warnings are two unknown
OpenRouter catalog models and four missing Kilroy status-path references.
It parses, but does not pass Kilroy's semantic validation.

Other files also lack explicit providers under Kilroy's rules, have unconditional
terminal edges, or use a model ID Kilroy considers noncanonical. Kilroy labels
the composition examples as agent nodes even though our implementation executes
`type=tool` and `type=subpipeline`; these need a compatibility assessment, not
provider attributes added blindly. Kilroy status-path environment variables and
model catalog naming are implementation-specific conventions.

In particular, do not mechanically add `condition="outcome=success"` to human
choice edges leading to exit. Under the upstream §3.3 ordering used here,
condition matches precede preferred-label and suggested-node choices: that
change would select exit regardless of the successful human answer. An explicit
intermediate completion node is one possible compatibility design to evaluate.

The current development DOT is the static local/repair/escalation loop. The
newly discussed recursive plan-to-DOT controller and paired adversarial review
workflow have not yet been generated; this result does not validate that design.

## Recursive compiler follow-up

The three generated graphs in `examples/recursive-development/` were checked
individually with the same binary/commit using `kilroy attractor validate --graph
<file>`. Results: `ok: task.dot`, `ok: task_0.dot`, `ok: task_0_0.dot`, all exit 0
and no diagnostics. These contain finite repair attempts and two review branches.
The native compiler also prepares the complete source closure successfully.

They use standard fallback tool shapes with `tool_command="false"` for unfinished
controller stages. This validates graph structure, not live coding/review or
Kilroy support for native captured subpipelines. The original six-file results
above remain historical and unchanged.

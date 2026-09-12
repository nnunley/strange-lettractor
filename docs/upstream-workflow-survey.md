# Reusable upstream DOT workflows

Checked 2026-09-11 using public repository trees and selected file contents.
The user's interest in Kilroy is importing useful workflows into our runtime,
not matching Kilroy's validator as an independent objective. The first import is now available: [adapted Amplifier task runner](../examples/task-runner/README.md).
Its native shell/engine contracts have deterministic execution coverage; live
model behavior remains unverified.

| Implementation | Existing workflow files | Most relevant starting point |
|---|---|---|
| [Microsoft Amplifier Attractor](https://github.com/microsoft/amplifier-bundle-attractor/tree/main/examples) | task-runner, objective-runner, pipeline-author, convergence-factory; practical bug-fix, feature-build, pr-review, multi-lens-review, refactor and test-gen; linear/branch/retry/parallel/HITL examples | Task runner plus independent review; objective runner for request-to-graph composition |
| [F#kYeah](https://github.com/TheFellow/fkyeah/tree/main/examples) | consensus_task, sdlc_grind_subtask, sprint_exec, megaplan_quality, semport, cedar_spec_port and others; separate conformance fixtures | Multi-model planning and subtask development loop |
| [StreamWeave Attractor](https://github.com/Industrial/streamweave-attractor/tree/main/examples/workflows) | ai-feature, ai-feature-plan, beads-worker-loop, pre-push and small execution examples | Existing feature/check/fix loop, with project-specific tools |
| [ashkavakil/attractor](https://github.com/ashkavakil/attractor/tree/main/examples) | hello_world.dot | Minimal compatibility smoke, not a substantial development workflow |
| [Kilroy](https://github.com/danshapiro/kilroy/tree/main/workflows) | coding-loop, build-test, multi-tool-exercise; demo graphs and docs/strongdm/dot specs | Coding-loop; consensus_task under its vendored DOT examples |

Selected source inspection:

- [Amplifier task-runner](https://github.com/microsoft/amplifier-bundle-attractor/blob/main/examples/patterns/task-runner.dot)
  implements an attempt/verify/critique loop, repeated-failure diagnosis,
  iteration budget, postmortem, human escalation and packaging. It relies on
  `$param` substitution, `tool.last_line`, filesystem artifacts and its engine's
  terminal/fidelity semantics. Those contracts must be mapped and exercised here.
- [Amplifier multi-lens-review](https://github.com/microsoft/amplifier-bundle-attractor/blob/main/examples/pipelines/practical/multi-lens-review.dot)
  runs three provider/lens branches and synthesizes their findings. Its current
  stylesheet uses a `box` selector and one branch uses the provider instance
  `luna`; these are not our current stylesheet grammar/provider configuration.
  It is a useful review pattern, not proof of enforced acceptance by itself.
- [Amplifier objective-runner](https://github.com/microsoft/amplifier-bundle-attractor/blob/main/examples/objective/objective-runner.dot)
  diagnoses an objective, selects a lane or composes a child graph, validates
  the composition and independently checks evidence. It relies on helper
  scripts/schema files and runtime child-graph generation. Our immutable source
  closure is captured before execution, so dynamic composition needs an explicit
  controller boundary; copying the DOT alone would not implement that behavior.
- [F#kYeah sdlc_grind_subtask](https://github.com/TheFellow/fkyeah/blob/main/examples/sdlc_grind_subtask.dot)
  plans subtask files, implements, validates, asks for review and commits in a
  loop. It uses `shape=tab`, `scope_gate`, `requires_green_build` and a dynamic
  thread ID, plus Go-specific commands. Its `go test -run=^$` compiles tests
  without running test cases; don't describe that gate as behavioral verification.
- [StreamWeave ai-feature](https://github.com/Industrial/streamweave-attractor/blob/main/examples/workflows/ai-feature.dot)
  uses `type=exec` / `command`, Nix `devenv`, `bd` tasks and automatic commit/push
  steps. Our tool handler uses `type=tool` / `tool_command`. These are concrete
  adaptation requirements, not drop-in equivalence.

Priority for the next implementation work: assess and adapt Amplifier's task
runner and review graph, then its objective/composition layer. Keep upstream
provenance and license notices with any copied files. Add execution evidence
for the adapted control-flow contracts before claiming compatibility. No
checked upstream graph has yet been shown to recursively split tasks according
to measured context budgets; retain that user requirement during adaptation.

Task-runner import checkpoint: pinned upstream source and license retained;
adapted graph passes 7 tests / 23 assertions through real shell gates and native
execution with scripted model nodes. Multi-lens review and objective composition
remain candidates for the next import.

The task runner now has a primary embedded paired-review variant via
`task-runner/bind-reviews`; the single-critic shell adaptation is preserved as
`shell-review.dot`. The underlying upstream source remains unchanged.

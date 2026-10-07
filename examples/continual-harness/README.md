# Continual Harness

The core harness works without a trainer. It adapts task instructions, memory,
skills, executable tools and subagent definitions during ordinary agent sessions.
Model training is a separate, explicitly configured workflow.

## Ordinary harness sessions

Enable `harness.enabled="true"` on a coding node. Set `harness.path` to an EDN or
JSON file for durable state. `harness.auto_refine="true"`, `harness.interval="8"`
and `harness.warmup="0"` schedule refinement by agent steps. Automatic refinement
uses four component passes and real tool-result history. Setting auto_refine false
disables automatic triggers; `harness.frozen="true"` also prevents explicit edits.
Host policy remains fixed; the adaptive task prompt is separately editable.

Edits and rollbacks reconcile the ledger with callable tools and persist configured
state. Dynamic source is compiled as a function, with cooperative cancellation
checks. This is not a security sandbox: host callbacks must cooperate with
cancellation, and dynamic tools retain their execution environment's capabilities.

## Optional model training

`co-learning.dot` uses the `co_learning` workflow handler. Copy
`co-learning.edn.sample` to `co-learning.edn`, configure your checkpoint and four
executable adapters, then run:

```sh
lgx run main.lg run examples/continual-harness/co-learning.dot --auto-approve
```

Configuration is checked only when this handler runs. No trainer is needed for
ordinary harness sessions. The repository supplies infrastructure and an offline
training fixture, not a pretrained reward model, teacher, GPU trainer or model
serving system. Configure those operator-owned components explicitly.

The handler preserves one native agent session across iterations. Each rollout
has a fixed number of agent steps, one tool round per step. The live harness and
history carry forward. The configured scorer receives contextual transitions;
low-reward windows go to the teacher, then to the trainer. Successful activation
changes the model used by the same session's next rollout.

### Adapter contract

Each command is an argv vector. Attractor appends two paths: the JSON request and
the JSON response to write. Paths are shell-quoted. Processes run through the
owned execution environment with deadlines and cancellation. Every response must
echo `request_id`; requests also carry stage, run and iteration identity.

- **score** receives `transitions` (observation, assistant action, tool results,
  answer and checkpoint identity), `harness` and window settings. Return `scores`
  containing exactly one `{id, reward}` per transition, with rewards in [0,1].
- **teacher** additionally receives selected contextual `windows`. Return one
  target per window: `{window_id, context, positions}`. Each position contains
  distinct nonnegative `token_ids` and matching `probabilities` summing to one.
- **train** receives those targets, `objective="soft_sft"`, operator `trainer`
  configuration, the current checkpoint and `output_checkpoint`. Write a new
  checkpoint file there; return `{checkpoint, objective:"soft_sft"}`. The previous
  checkpoint must remain immutable. The concrete soft-SFT interpretation here is
  teacher token-distribution cross entropy; tokenizer compatibility is the
  operator's responsibility.
- **activate** receives checkpoint path/digest and previous checkpoint. Return
  `{model:"provider/model-name", checkpoint_sha256}` only after that artifact is
  usable by inference. Keep the same provider protocol. Implement transactional,
  idempotent activation keyed by `request_id`; an unsuccessful acknowledgment does
  not advance Attractor's active-checkpoint pointer.

Initial checkpoint provenance identifies an operator-pretrained checkpoint or
records prior SFT/GRPO preparation. This implementation does not silently perform
that preparation. Trainer hyperparameters, including shard accumulation, belong
in the recorded `trainer` configuration. Empty low-reward selection skips training.
A checkpoint is one file; use a self-contained artifact or extend the adapter
contract explicitly for sharded models. Checkpoint and JSON size limits are
configurable; the durable journal has a 16 MiB limit.

### Recovery and state boundaries

The private run directory stores stage requests, responses, checkpoint artifacts,
iteration results, harness and an atomic journal. A writer lock rejects concurrent
runs. On a cleanly reported scoring/training failure, rerun the same configuration:
completed rollouts are reused, preserving their history and harness. Declare every
file containing durable task state in `environment_files`; resume verifies their
hashes. Remote simulators need their own durable state adapter before this local
file-based continuity check is sufficient.

An interrupted rollout is deliberately not replayed: environment actions may
already have happened. Inspect the environment and journal and establish recovery
evidence before repairing its marker. A crash may also leave a writer lock; remove
it only after confirming the owner is gone. No exactly-once guarantee is made for
an external command that ignores the idempotency contract.

## Verification

```sh
lgx test-ns attractor.continual-harness-test
lgx test-ns attractor.co-learning-test
```

The offline fixture trains a Bernoulli policy from teacher probabilities, writes
changed weights, and checks that the next native rollout consumes them. It proves
infrastructure dataflow, not foundation-model quality or the paper's empirical
results. See [the audit](../../docs/codebase-audit-2026-10-07.md) for baseline defects
and evidence, and [the target paper](https://arxiv.org/abs/2605.09998).

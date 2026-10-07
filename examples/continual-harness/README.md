# Continual Harness in Attractor (arXiv:2605.09998)

This directory demonstrates the implementation of **Continual Harness: Online Adaptation for Self-Improving Foundation Agents** ([arXiv:2605.09998](https://arxiv.org/abs/2605.09998)) in Attractor.

## Overview

Continual Harness formalizes a **reset-free, online in-context adaptation loop** over the complete harness state $\mathcal{H} = (p, \mathcal{G}, \mathcal{K}, \mathcal{M})$:

- **$p$ (System Prompt):** Supplemental strategic prompt guidance injected dynamically into the system prompt.
- **$\mathcal{G}$ (Sub-Agents):** Reusable, specialized subagent specifications that can be invoked via `spawn_agent` with custom roles.
- **$\mathcal{K}$ (Skills):** Reusable runtime procedures and heuristics.
- **$\mathcal{M}$ (Memory):** Persistent long-term memory for facts, milestones, obstacles, and lessons.

## Architecture

### 1. In-Context Coding Agent Loop (`attractor.agent` & `attractor.harness`)

When an agent session runs with Continual Harness enabled:
- **Ledger:** The session maintains an atom holding $\mathcal{H}$, persisted across turns and serialized to disk (`harness_state.edn` or `.json`).
- **Prompt Injection:** On every turn, `assemble-system-prompt` injects the `# Continual Harness State` section.
- **Loop Trigger:** When `detect-loop` identifies repeated tool-call patterns, it triggers the LLM Refiner (`attractor.refiner`) immediately to diagnose the failure and apply CRUD updates to $\mathcal{H}$ reset-free.
- **Meta-Tools:** The agent has direct access to:
  - `remember`: Save lessons, facts, or milestones to long-term memory.
  - `recall`: Query persistent memory entries.
  - `define_subagent`: Define specialized subagent roles.
  - `refine_harness`: Explicitly request harness adaptation when encountering blockers.

### 2. Workflow Co-Learning Pipeline (`co-learning.dot`)

The workflow pipeline illustrates Section 3.3 of the paper:
- **`rollout`**: Executes steps through the live-refining harness with full thread fidelity (`fidelity="full"`), preserving environment and harness state reset-free.
- **`prm_score`**: Process Reward Model evaluates trajectory shards.
- **`teacher_relabel`**: Frontier teacher relabels low-reward windows.
- **`soft_sft`**: Policy weights update while emulator and harness state carry forward into the next iteration.

## Running Tests

Run the Continual Harness test suite:

```bash
lgx test-ns attractor.harness-test
lgx test-ns attractor.refiner-test
lgx test-ns attractor.continual-harness-test
```

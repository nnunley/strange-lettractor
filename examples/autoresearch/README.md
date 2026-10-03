# autoresearch as a workflow

The loop from [karpathy/autoresearch](https://github.com/karpathy/autoresearch):
propose one change, run the experiment under a fixed budget, keep the change if
the metric improved, reset if it did not, log it, repeat, never stop.

Here the loop is a DOT workflow. The model only **proposes edits**. Everything
that must hold is a tool node, so it holds whatever the model does:

| Rule in the original `program.md` | Here |
|---|---|
| Edit only `train.py` | `guard`: changed files must match `EDITABLE`, else the work is rejected and reverted |
| git commit the idea | `guard` makes the commit; the model never uses git |
| 5 minute budget, kill at 10 | `timeout` on the `run` node; a timeout is a crash |
| `grep "^val_bpb:"` | `measure` with `METRIC_REGEX`; no metric is a crash |
| Fix a dumb crash, else give up | `can_repair` → `repair` → `amend`, at most `MAX_REPAIRS` times, then `give_up` |
| Keep if improved, else `git reset` | `decide`: better than best by more than `EPSILON` keeps; a tie keeps only a simplification (more lines removed than added) |
| `results.tsv`, untracked | `commit metric status description`, excluded via `.git/info/exclude`; the header says which way is better, and a crashed or rejected row has no metric |
| The first run is the baseline | `baseline_run` → `baseline_measure` → `baseline_keep` |
| LOOP FOREVER | `again -> begin` with `loop_restart=true` (a fresh run segment per iteration); `MAX_ITERATIONS=0` never stops |

It is language-neutral: the experiment is whatever `RUN_CMD` says. Two demo
targets ship here, the same problem in Python and in let-go.

## Files

- `autoresearch.dot` the workflow
- `ar.sh` the mechanical steps the tool nodes call (POSIX sh, no dependencies)
- `program.md` the researcher's standing instructions (edit to steer it)
- `research.env.sample` per-run configuration
- `targets/py-primes`, `targets/lg-primes` demo targets; `new-target.sh` scaffolds one

## Try it

The loop creates a branch and uses `git reset --hard`, so a target is always
**its own git repository**; `ar.sh` refuses to act off an `autoresearch/*` branch.

    sh new-target.sh py-primes /tmp/ar-py
    cd /tmp/ar-py
    attractor run autoresearch/autoresearch.dot --logs-root attractor_runs

    sh new-target.sh lg-primes /tmp/ar-lg
    cd /tmp/ar-lg
    LG=/path/to/lg attractor run autoresearch/autoresearch.dot --logs-root attractor_runs

Then read `results.tsv` and `git log`: the branch holds exactly the kept ideas.
The demos stop after `MAX_ITERATIONS=3`.

## Use it on your own project

1. Copy `ar.sh`, `autoresearch.dot`, `program.md` into `<repo>/autoresearch/`.
2. Write `<repo>/research.env` from `research.env.sample`: `EDITABLE`, `RUN_CMD`,
   `METRIC_REGEX`, `DIRECTION` (`min` or `max`, anything else is refused, and
   `setup` refuses a `GOAL` that says maximize under `min` or the reverse), a
   fresh `TAG`.
3. Make the experiment print its metric on one line and **exit non-zero on a
   wrong result**, so a fast wrong answer is a crash, not a win.
4. Optionally add `notes.md`: what the researcher needs to know about the
   codebase or language. (The let-go demo needs it: without it the model writes
   JVM Clojure and every experiment crashes.)
5. Set the per-experiment budget: `timeout` on `run` and `baseline_run`.
6. Pick the researcher's model in the stylesheet, using the fully qualified
   name `attractor models` prints, e.g. `openrouter/anthropic/claude-haiku-4.5`.
7. Commit, then from the repo root: `attractor run autoresearch/autoresearch.dot`.

## Differences from the original

- The keep rule is mechanical. The original lets the agent weigh complexity
  against gain; here a tie is kept only when the change removes code.
- The model cannot break the rules by ignoring them; the guard and the
  timeout do not depend on its cooperation.
- There is no memory/VRAM column. Add one by extending `measure` and `row`.

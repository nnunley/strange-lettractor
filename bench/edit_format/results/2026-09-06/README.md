# Completed paired trial

All 108 scheduled runs completed. The mechanical report validator accepted the
dataset. No human or model verdict determined a run's correctness.

| Read format | First edit matched | Correct, including preservation | Model requests | Total tokens |
|---|---:|---:|---:|---:|
| Existing `N | ` | 36/36 | 36/36 | 110 | 92,103 |
| Tight `N |` | 36/36 | 36/36 | 113 | 93,408 |
| Raw source + metadata header | 35/36 | 35/36 | 116 | 90,381 |

All 107 attempted edits matched on their first attempt. No protected-block
violations or generation exceptions occurred. The sole unsuccessful run,
`lg-blank-lines-1-raw`, spent four tool rounds reading, then requested its first
edit after the execution budget had been exhausted. Its source remained
unchanged and failed the executable check. It was not an indentation mismatch.

Paired correctness: existing versus tight tied in all 36 pairs. Each numbered
format had one exclusive success versus raw, with the other 35 pairs tied.

Total: 339 model requests, 255,752 input tokens, 20,140 output tokens, and
422,405 ms summed model/tool operation time (excluding fixture-validation and
independent checker time). Timing is descriptive, not a throughput benchmark.

## Interpretation and limits

This batch does **not** demonstrate a reliability advantage for the tighter
separator. It also does not disprove the delimiter-confusion mechanism observed
in the original task and six-run targeted probe. These 12 synthetic fixes were
mostly achievable with short, unique replacements; performance was near the
ceiling and no exact-match failure occurred. They are not a replay of the larger
real development task. Do not pool this dataset with the earlier differently
configured trials or generalize it to all Qwen models/tasks.

Production read formatting and exact editing remain unchanged. A useful next
study would replay difficult multi-line edits and the original task with matched
context and budgets, rather than simply increasing repeats of these easy fixes.

## Reproduce the mechanical report

From the repository root:

```sh
/Users/ndn/development/let-go/lg -source-paths bench -e '(require (quote [edit-format.report :as r])) (r/report! "bench/edit_format/results/2026-09-06")'
```

`manifest.edn` pins the live harness revision/settings and server identity hashes;
`results.edn` preserves all trial metrics and executable-check evidence;
`report.edn` is mechanically regenerated, with per-task/language totals and paired
comparisons. Full local model/tool transcripts and candidate files are retained
under `/tmp/lettractor-edit-benchmark-full`, separately from the committed compact
results. The pilot runs are excluded from these 108 observations.

#!/bin/sh
# Mechanical half of the autoresearch loop (after karpathy/autoresearch).
# The workflow's tool nodes call one subcommand each; the LLM only proposes
# edits. Run from the root of the TARGET repository. Language-neutral: the
# experiment is whatever RUN_CMD says (python, lg, make, ...).
#
# Config: ./research.env (or $AR_CONFIG). State: .autoresearch/ (untracked).
set -eu

CONFIG=${AR_CONFIG:-research.env}
[ -f "$CONFIG" ] || { echo "missing $CONFIG (copy research.env.sample)" >&2; exit 2; }
. "./$CONFIG"
: "${TAG:?set TAG}" "${EDITABLE:?set EDITABLE}" "${RUN_CMD:?set RUN_CMD}" "${METRIC_REGEX:?set METRIC_REGEX}"
DIRECTION=${DIRECTION:-min}        # min: lower is better; max: higher is better
EPSILON=${EPSILON:-0}              # improvements no larger than this count as ties
MAX_ITERATIONS=${MAX_ITERATIONS:-0} # 0 = never stop
MAX_REPAIRS=${MAX_REPAIRS:-2}      # crash-fix attempts per idea
case "$DIRECTION" in
  min|max) ;;
  *) echo "DIRECTION must be min or max, not '$DIRECTION'" >&2; exit 2 ;;
esac
STATE=.autoresearch
RESULTS=results.tsv

on_research_branch() {
  case "$(git rev-parse --abbrev-ref HEAD)" in
    autoresearch/*) ;;
    *) echo "refusing: not on an autoresearch/* branch" >&2; exit 2 ;;
  esac
}
short() { git rev-parse --short=7 "${1:-HEAD}"; }
description() { head -n 1 "$STATE/description" 2>/dev/null | tr '\t' ' ' || true; }
row() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$RESULTS"; }  # metric is empty when nothing was measured
discard_work() { git reset -q --hard "$(cat "$STATE/base")"; git clean -qfd; }

case "${1:-}" in
setup)
  git rev-parse --git-dir >/dev/null
  # The researcher reads GOAL; decide reads DIRECTION. Catch the two disagreeing.
  case "$DIRECTION:$(printf '%s' "${GOAL:-}" | tr '[:upper:]' '[:lower:]')" in
    min:*maximi[sz]e*|max:*minimi[sz]e*)
      echo "GOAL says \"$GOAL\" but DIRECTION=$DIRECTION: fix one of them" >&2; exit 1 ;;
  esac
  branch="autoresearch/$TAG"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "branch $branch already exists: pick a fresh TAG" >&2; exit 1
  fi
  exclude="$(git rev-parse --git-dir)/info/exclude"
  for path in "$RESULTS" run.log "$STATE/" attractor_runs/; do
    grep -qxF "$path" "$exclude" 2>/dev/null || echo "$path" >> "$exclude"
  done
  [ -z "$(git status --porcelain)" ] || { echo "working tree is dirty: commit or stash first" >&2; exit 1; }
  git checkout -q -b "$branch"
  mkdir -p "$STATE"
  better=lower; [ "$DIRECTION" = max ] && better=higher
  printf 'commit\tmetric (%s is better)\tstatus\tdescription\n' "$better" > "$RESULTS"
  rm -f "$STATE/best" "$STATE/repairs"; echo 0 > "$STATE/iterations"
  echo "baseline" > "$STATE/description"
  short > "$STATE/base"
  echo "on $branch; results in $RESULTS"
  ;;

begin)   # before each proposal: remember where to fall back to
  on_research_branch
  short > "$STATE/base"; rm -f "$STATE/repairs" "$STATE/description"
  # Experiments leave by-products (caches, build output). Whatever is already
  # dirty now is not the agent's doing, so the guard ignores it.
  git status --porcelain | sed 's/^...//' | sort > "$STATE/preexisting"
  ;;

guard)   # the agent may touch EDITABLE only; the commit is made here, not by the agent
  on_research_branch
  touch "$STATE/preexisting"
  changed=$(git status --porcelain | sed 's/^...//' | sort | comm -23 - "$STATE/preexisting")
  [ -n "$changed" ] || { echo "no change was made" >&2; exit 1; }
  for file in $changed; do
    ok=0
    for allowed in $EDITABLE; do
      case "$file" in $allowed) ok=1 ;; esac
    done
    if [ "$ok" = 0 ]; then
      echo "forbidden edit: $file (allowed: $EDITABLE)" >&2
      row "$(short)" "" discard "rejected: touched $file"
      discard_work; exit 1
    fi
  done
  [ -s "$STATE/description" ] || echo "(no description given)" > "$STATE/description"
  git add -- $changed
  git commit -q -m "experiment: $(description)"
  echo "committed $(short): $(description)"
  ;;

run)     # the node's timeout is the experiment's time budget
  on_research_branch
  sh -c "$RUN_CMD" > run.log 2>&1
  ;;

measure)
  value=$(grep -E "$METRIC_REGEX" run.log | tail -n 1 | grep -Eo '[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?' | tail -n 1 || true)
  [ -n "$value" ] || { echo "no metric matching $METRIC_REGEX in run.log:" >&2; tail -n 20 run.log >&2; exit 1; }
  echo "$value" > "$STATE/metric"; echo "metric $value"
  ;;

decide)  # keep if better; on a tie keep only a simplification; else reset
  on_research_branch
  metric=$(cat "$STATE/metric")
  if [ ! -f "$STATE/best" ]; then
    echo "$metric" > "$STATE/best"; row "$(short)" "$metric" keep "$(description)"
    echo "baseline $metric"; exit 0
  fi
  best=$(cat "$STATE/best")
  verdict=$(awk -v m="$metric" -v b="$best" -v e="$EPSILON" -v d="$DIRECTION" 'BEGIN{
    gain = (d=="max") ? m-b : b-m; print (gain>e) ? "better" : (gain>=-e ? "tie" : "worse") }')
  if [ "$verdict" = tie ]; then
    stat=$(git diff --numstat "$(cat "$STATE/base")" HEAD | awk '{a+=$1; d+=$2} END{print (d>a) ? "simpler" : "not"}')
    [ "$stat" = simpler ] && verdict=better
  fi
  if [ "$verdict" = better ]; then
    echo "$metric" > "$STATE/best"; row "$(short)" "$metric" keep "$(description)"
    echo "keep $metric (was $best)"
  else
    row "$(short)" "$metric" discard "$(description)"
    discard_work; echo "discard $metric (best $best)"
  fi
  ;;

can-repair)  # a crash: is another fix attempt allowed for this idea?
  used=$(cat "$STATE/repairs" 2>/dev/null || echo 0)
  [ "$used" -lt "$MAX_REPAIRS" ] || exit 1
  echo $((used + 1)) > "$STATE/repairs"
  tail -n 50 run.log > "$STATE/crash.log" 2>/dev/null || true
  echo "repair attempt $((used + 1)) of $MAX_REPAIRS"
  ;;

amend)   # fold a crash fix into the experiment commit, under the same guard
  on_research_branch
  "$0" guard >/dev/null 2>&1 || { echo "repair changed nothing allowed" >&2; exit 1; }
  git reset -q --soft "$(cat "$STATE/base")" && git commit -q -m "experiment: $(description)"
  ;;

give-up)
  on_research_branch
  row "$(short)" "" crash "$(description)"
  discard_work; echo "crash logged, reverted"
  ;;

continue)  # exit 0 to loop again, 1 to stop (only when a limit is configured)
  count=$(( $(cat "$STATE/iterations") + 1 )); echo "$count" > "$STATE/iterations"
  if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$count" -ge "$MAX_ITERATIONS" ]; then
    echo "stopping after $count iterations"; exit 1
  fi
  echo "iteration $count done"
  ;;

*) echo "usage: ar.sh setup|begin|guard|run|measure|decide|can-repair|amend|give-up|continue" >&2; exit 2 ;;
esac

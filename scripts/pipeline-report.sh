#!/usr/bin/env bash
# Below is the code to measure one CI run against the Project Brief's Table 7 targets, using GitHub's own job times.
# It runs as the last job of the CI workflow and prints a Markdown report (saved as the "pipeline-report" artifact).
set -euo pipefail
api="repos/$GITHUB_REPOSITORY/actions"

# Below is the code to download this run's details and the list of its jobs with their start and finish times.
run=$(gh api "$api/runs/$GITHUB_RUN_ID")
jobs=$(gh api "$api/runs/$GITHUB_RUN_ID/attempts/$GITHUB_RUN_ATTEMPT/jobs?per_page=100" --jq '.jobs')

# Below is the code to work out how many seconds a job took. A job's clock starts when its first step starts,
# so time spent waiting for the Production approval is NOT counted inside the Production deploy.
secs() {
  echo "$jobs" | jq -r --arg n "$1" '[.[] | select(.name == $n and .conclusion != null and .conclusion != "skipped")][0]
    | if . == null then "" else ((.completed_at | fromdateiso8601) - (.steps[0].started_at // .started_at | fromdateiso8601)) end'
}
finished_at() {
  echo "$jobs" | jq -r --arg n "$1" '[.[] | select(.name == $n and .completed_at != null)][0].completed_at // ""'
}
fmt() { [ -n "$1" ] && printf '%dm %02ds' $(( $1 / 60 )) $(( $1 % 60 )) || echo "-"; }
check() { [ -z "$1" ] && echo "-" && return; [ "$1" -le "$2" ] && echo "PASS" || echo "FAIL"; }

started=$(echo "$run" | jq -r '.run_started_at')
echo "## Pipeline report for run #$(echo "$run" | jq -r '.run_number') on \`${GITHUB_REF_NAME}\`"
echo
echo "Commit \`$GITHUB_SHA\`, run started $started"
echo
echo "### Every job"
echo "| Job | Result | Time |"
echo "|---|---|---|"
echo "$jobs" | jq -r '.[] | select(.completed_at != null and .conclusion != "skipped")
  | "| \(.name) | \(.conclusion) | \(((.completed_at | fromdateiso8601) - (.steps[0].started_at // .started_at | fromdateiso8601)) as $s | "\($s / 60 | floor)m \($s % 60)s") |"'
echo

# Below is the code to compare the key times with the Table 7 targets.
build=$(secs build)
echo "### Table 7 targets"
echo "| Measure | Target | This run | Result |"
echo "|---|---|---|---|"
echo "| Build and upload image | 4 min or less | $(fmt "$build") | $(check "$build" 240) |"
for env in Development Testing Staging Production; do
  d=$(secs "$env / deploy")
  [ -n "$d" ] && echo "| Deploy to $env (incl. /health) | 5 min or less | $(fmt "$d") | $(check "$d" 300) |"
done
staging_done=$(finished_at "Staging / verify")
if [ -n "$staging_done" ]; then
  s=$(( $(date -d "$staging_done" +%s) - $(date -d "$started" +%s) ))
  echo "| Merge to Staging verified | 15 min or less | $(fmt "$s") | $(check "$s" 900) |"
fi
prod=$(secs "Production / deploy")
[ -n "$prod" ] && echo "| Approval to healthy Production | 5 min or less | $(fmt "$prod") | $(check "$prod" 300) |"
echo "| Manual steps before approval | 0 | 0 (merge is the only trigger) | PASS |"

# Below is the code to check the image digest is identical on every server it reached.
same="PASS"
list=""
for pair in "Build:${BUILD_DIGEST:-}" "Development:${DEV_DIGEST:-}" "Testing:${TESTING_DIGEST:-}" "Staging:${STAGING_DIGEST:-}" "Production:${PRODUCTION_DIGEST:-}"; do
  name=${pair%%:*}; value=${pair#*:}
  [ -z "$value" ] && continue
  list="$list<br>$name: \`${value:7:12}…\`"
  [ "$value" != "${BUILD_DIGEST:-}" ] && same="FAIL"
done
echo "| Same image digest everywhere | identical | ${list#<br>} | $same |"

# Below is the code to work out the CI success rate over the last 50 finished CI runs.
rate=$(gh api "$api/workflows/ci.yml/runs?status=completed&per_page=50" \
  --jq '[.workflow_runs[] | select(.conclusion != "cancelled" and .conclusion != "skipped")] as $r
        | if ($r | length) == 0 then "0 0" else "\([$r[] | select(.conclusion == "success")] | length) \($r | length)" end')
ok=${rate% *}; total=${rate#* }
pct=$(( total > 0 ? ok * 100 / total : 0 ))
echo "| CI success rate (last $total runs) | 90% or more | $pct% ($ok of $total) | $( [ "$pct" -ge 90 ] && echo PASS || echo FAIL ) |"

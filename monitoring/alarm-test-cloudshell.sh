#!/bin/bash
# Below is the code to trigger the Level 2 alarms with real traffic sent to Production from CloudShell (outside the server).
# "latency" and "errors" need the fault pages ON first (on Production: prod-fault-injection.sh on) and OFF afterwards.

# Below is the code to stop at the first error, load config.sh, and set Production's web address.
set -euo pipefail
source "$(dirname "$0")/config.sh"
URL="http://${PROD_IP}"

# Below is the code to print how to use this script (shown when it is run without a valid test name).
usage() {
  echo "Level 2, step 9. Alarm triggers that run from CloudShell (real HTTP traffic into Production):"
  echo "  bash alarm-test-cloudshell.sh traffic      -> 5 min of normal page loads (fills the dashboard)"
  echo "  bash alarm-test-cloudshell.sh latency      -> 7 min of slow requests, fires latency-p95-high"
  echo "  bash alarm-test-cloudshell.sh errors       -> 30 x HTTP 500 in about 1 min, fires http-5xx"
  echo "  bash alarm-test-cloudshell.sh statuscheck  -> SIMULATION: set-alarm-state on status-check-failed"
  echo "latency and errors need the fault routes ON first (on Production: prod-fault-injection.sh on) and OFF afterwards."
}

# Below is the code to stop with a clear message unless the fault test pages are switched on.
need_faults() {
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/_fault/500")
  [ "$code" = 500 ] || { echo "Fault routes are OFF ($URL/_fault/500 gave $code). On Production run: prod-fault-injection.sh on"; exit 1; }
}

# Below is the code to run the test named on the command line.
case "${1:-}" in
  # Below is the code to send 5 minutes of normal page loads to Production, so the dashboard graphs have data.
  traffic)
    log "traffic: START - 5 min of normal requests to $URL"
    end=$(( $(date +%s) + 300 )); n=0
    while [ "$(date +%s)" -lt "$end" ]; do
      for p in / /version /does-not-exist; do curl -s -o /dev/null "$URL$p"; n=$((n+1)); done
      sleep 1
    done
    log "traffic: END - $n requests sent"
    ;;
  # Below is the code to send 7 minutes of slow (800 ms) requests from 2 loops at once, to fire latency-p95-high.
  latency)
    need_faults
    log "latency: START - 2 parallel loops of 800 ms requests for 7 min"
    end=$(( $(date +%s) + 420 ))
    for w in 1 2; do
      ( while [ "$(date +%s)" -lt "$end" ]; do
          curl -s -o /dev/null -w "worker$w %{http_code} %{time_total}s\n" "$URL/_fault/slow?ms=800"
        done ) > "/tmp/latency-worker$w.log" &
    done
    wait
    log "latency: END - $(cat /tmp/latency-worker*.log | wc -l) slow requests sent. Sample:"
    head -n 5 /tmp/latency-worker1.log
    ;;
  # Below is the code to request the error test page 30 times in about a minute, to fire http-5xx.
  errors)
    need_faults
    log "errors: START - 30 requests to /_fault/500"
    for i in $(seq 30); do
      echo "request $i -> HTTP $(curl -s -o /dev/null -w '%{http_code}' "$URL/_fault/500")"
      sleep 2
    done
    log "errors: END"
    ;;
  # Below is the code to test only the alarm -> SNS -> email path, because a status check cannot be failed safely
  # on purpose. Label it as a SIMULATION in the report.
  statuscheck)
    aws cloudwatch set-alarm-state --alarm-name "${ALARM_PREFIX}-status-check-failed" --state-value ALARM \
      --state-reason "SIMULATION for Level 2 evidence: notification path test, not a real failure"
    log "statuscheck: alarm set to ALARM (simulation). It returns to OK at the next evaluation."
    ;;
  # Below is the code to show the usage help for anything else.
  *) usage; exit 1 ;;
esac

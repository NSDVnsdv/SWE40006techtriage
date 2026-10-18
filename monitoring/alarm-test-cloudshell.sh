#!/bin/bash
# Level 2, step 9. Alarm triggers that run from CloudShell, i.e. real HTTP
# traffic coming into Production from outside the server.
#   bash alarm-test-cloudshell.sh traffic      # 5 min of normal page loads (fills the dashboard)
#   bash alarm-test-cloudshell.sh latency      # 7 min of slow requests -> latency-p95-high
#   bash alarm-test-cloudshell.sh errors       # 30 x HTTP 500 in ~1 min  -> http-5xx
#   bash alarm-test-cloudshell.sh statuscheck  # SIMULATION: set-alarm-state on status-check-failed
# latency and errors need the fault routes ON first (on Production:
# prod-fault-injection.sh on) and OFF again afterwards.
set -euo pipefail
source "$(dirname "$0")/config.sh"
URL="http://${PROD_IP}"

need_faults() {
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/_fault/500")
  [ "$code" = 500 ] || { echo "Fault routes are OFF ($URL/_fault/500 gave $code). On Production run: prod-fault-injection.sh on"; exit 1; }
}

case "${1:-}" in
  traffic)
    log "traffic: START - 5 min of normal requests to $URL"
    end=$(( $(date +%s) + 300 )); n=0
    while [ "$(date +%s)" -lt "$end" ]; do
      for p in / /version /does-not-exist; do curl -s -o /dev/null "$URL$p"; n=$((n+1)); done
      sleep 1
    done
    log "traffic: END - $n requests sent"
    ;;
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
  errors)
    need_faults
    log "errors: START - 30 requests to /_fault/500"
    for i in $(seq 30); do
      echo "request $i -> HTTP $(curl -s -o /dev/null -w '%{http_code}' "$URL/_fault/500")"
      sleep 2
    done
    log "errors: END"
    ;;
  statuscheck)
    # A status check cannot be failed safely on purpose, so this only tests the
    # alarm -> SNS -> email path. Label it as a SIMULATION in the report.
    aws cloudwatch set-alarm-state --alarm-name "${ALARM_PREFIX}-status-check-failed" --state-value ALARM \
      --state-reason "SIMULATION for Level 2 evidence: notification path test, not a real failure"
    log "statuscheck: alarm set to ALARM (simulation). It returns to OK at the next evaluation."
    ;;
  *) sed -n '2,10p' "$0"; exit 1 ;;
esac

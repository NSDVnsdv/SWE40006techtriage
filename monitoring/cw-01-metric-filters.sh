#!/bin/bash
# Level 2, step 4. Run in AWS CloudShell (us-east-1) from the monitoring folder:
#   bash cw-01-metric-filters.sh
# Turns the app's JSON access-log lines into three custom metrics:
#   RequestCount   1 per request (excluding /health probes)
#   RequestLatency the request's duration_ms (graph p50/p95)
#   Http5xxCount   1 per response with status >= 500
set -euo pipefail
source "$(dirname "$0")/config.sh"

log "Log group $APP_LOG_GROUP (created by Docker in step 2; created here if missing)"
aws logs create-log-group --log-group-name "$APP_LOG_GROUP" 2>/dev/null || true
aws logs put-retention-policy --log-group-name "$APP_LOG_GROUP" --retention-in-days 7

put_filter() { # name pattern metric value unit default
  local t="{\"metricName\":\"$3\",\"metricNamespace\":\"$NS\",\"metricValue\":\"$4\",\"unit\":\"$5\""
  [ -n "${6:-}" ] && t="$t,\"defaultValue\":$6"
  aws logs put-metric-filter --log-group-name "$APP_LOG_GROUP" \
    --filter-name "$1" --filter-pattern "$2" --metric-transformations "[$t}]"
  log "metric filter $1 -> $NS/$3"
}

put_filter techtriage-request-count   '{ $.type = "access" && $.path != "/health" }' RequestCount   1              Count        0
put_filter techtriage-request-latency '{ $.type = "access" && $.path != "/health" }' RequestLatency '$.duration_ms' Milliseconds
put_filter techtriage-http-5xx        '{ $.type = "access" && $.status >= 500 }'     Http5xxCount   1              Count        0

aws logs describe-metric-filters --log-group-name "$APP_LOG_GROUP" \
  --query 'metricFilters[].[filterName, filterPattern, metricTransformations[0].metricName]' --output table

log "Test the patterns against real log lines from the last 10 minutes:"
aws logs filter-log-events --log-group-name "$APP_LOG_GROUP" \
  --filter-pattern '{ $.type = "access" }' --start-time $(( ($(date +%s) - 600) * 1000 )) \
  --max-items 5 --query 'events[].message' --output text

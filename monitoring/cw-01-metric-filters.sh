#!/bin/bash
# Below is the code to turn the app's JSON access-log lines into 3 CloudWatch metrics: RequestCount, RequestLatency (ms)
# and Http5xxCount. Run it in AWS CloudShell from the monitoring folder: bash cw-01-metric-filters.sh

# Below is the code to stop at the first error and load the shared settings from config.sh.
set -euo pipefail
source "$(dirname "$0")/config.sh"

# Below is the code to make sure the app's log group exists (Docker normally creates it) and keeps 7 days of logs.
log "Log group $APP_LOG_GROUP (created by Docker in step 2; created here if missing)"
aws logs create-log-group --log-group-name "$APP_LOG_GROUP" 2>/dev/null || true
aws logs put-retention-policy --log-group-name "$APP_LOG_GROUP" --retention-in-days 7

# Below is the code to create one metric filter. Its inputs are, in order: filter name, log pattern, metric name,
# the value to record, the unit, and an optional default value.
put_filter() {
  local t="{\"metricName\":\"$3\",\"metricNamespace\":\"$NS\",\"metricValue\":\"$4\",\"unit\":\"$5\""
  [ -n "${6:-}" ] && t="$t,\"defaultValue\":$6"
  aws logs put-metric-filter --log-group-name "$APP_LOG_GROUP" \
    --filter-name "$1" --filter-pattern "$2" --metric-transformations "[$t}]"
  log "metric filter $1 -> $NS/$3"
}

# Below is the code to create the 3 filters: count each request (ignoring /health probes), record each request's
# duration_ms (for the p50/p95 graphs), and count every response with a status of 500 or above.
put_filter techtriage-request-count   '{ $.type = "access" && $.path != "/health" }' RequestCount   1              Count        0
put_filter techtriage-request-latency '{ $.type = "access" && $.path != "/health" }' RequestLatency '$.duration_ms' Milliseconds
put_filter techtriage-http-5xx        '{ $.type = "access" && $.status >= 500 }'     Http5xxCount   1              Count        0

# Below is the code to list the filters that are now in place.
aws logs describe-metric-filters --log-group-name "$APP_LOG_GROUP" \
  --query 'metricFilters[].[filterName, filterPattern, metricTransformations[0].metricName]' --output table

# Below is the code to test the patterns against real log lines from the last 10 minutes.
log "Test the patterns against real log lines from the last 10 minutes:"
aws logs filter-log-events --log-group-name "$APP_LOG_GROUP" \
  --filter-pattern '{ $.type = "access" }' --start-time $(( ($(date +%s) - 600) * 1000 )) \
  --max-items 5 --query 'events[].message' --output text

#!/bin/bash
# Level 2, step 7. Run in CloudShell:  bash cw-04-alarms.sh
# Creates the 7 Production alarms from Table 9 of the Project Brief. Every
# alarm emails the SNS topic when it fires (ALARM) and when it clears (OK).
# Safe to re-run: put-metric-alarm updates an alarm with the same name.
set -euo pipefail
source "$(dirname "$0")/config.sh"

IID=$(instance_id); TOPIC=$(topic_arn); HC=$(health_check_id)
DISK_DIMS=$(disk_dimensions "$IID")
log "instance=$IID topic=$TOPIC healthcheck=$HC"
[ "$TOPIC" != "None" ] || { echo "Run cw-02-sns.sh first"; exit 1; }
[ "$DISK_DIMS" != "null" ] || { echo "No disk_used_percent metric yet: is the CloudWatch Agent running (step 3)?"; exit 1; }

alarm() { # name description, then put-metric-alarm options
  local name="${ALARM_PREFIX}-$1" desc="$2"; shift 2
  aws cloudwatch put-metric-alarm --alarm-name "$name" --alarm-description "$desc" \
    --alarm-actions "$TOPIC" --ok-actions "$TOPIC" "$@"
  log "alarm $name"
}

alarm cpu-high "Saturation: CPU average above 70% for 2 x 5-minute periods" \
  --namespace AWS/EC2 --metric-name CPUUtilization --dimensions Name=InstanceId,Value="$IID" \
  --statistic Average --period 300 --evaluation-periods 2 --datapoints-to-alarm 2 \
  --threshold 70 --comparison-operator GreaterThanThreshold --treat-missing-data missing

alarm memory-high "Saturation: memory used above 80% for 5 minutes (CloudWatch Agent)" \
  --namespace "$NS" --metric-name mem_used_percent --dimensions Name=InstanceId,Value="$IID" \
  --statistic Average --period 60 --evaluation-periods 5 --datapoints-to-alarm 5 \
  --threshold 80 --comparison-operator GreaterThanThreshold --treat-missing-data missing

alarm disk-high "Saturation: root disk used above 80% (CloudWatch Agent)" \
  --namespace "$NS" --metric-name disk_used_percent --dimensions "$DISK_DIMS" \
  --statistic Average --period 60 --evaluation-periods 1 \
  --threshold 80 --comparison-operator GreaterThanThreshold --treat-missing-data missing

alarm latency-p95-high "Latency: p95 response time above 500 ms for 5 minutes (access-log metric filter)" \
  --namespace "$NS" --metric-name RequestLatency \
  --extended-statistic p95 --period 60 --evaluation-periods 5 --datapoints-to-alarm 5 \
  --threshold 500 --comparison-operator GreaterThanThreshold --treat-missing-data notBreaching

alarm http-5xx "Errors: more than 5 HTTP 5xx responses in 5 minutes (access-log metric filter)" \
  --namespace "$NS" --metric-name Http5xxCount \
  --statistic Sum --period 300 --evaluation-periods 1 \
  --threshold 5 --comparison-operator GreaterThanThreshold --treat-missing-data notBreaching

alarm status-check-failed "Errors: EC2 status check failed for 2 periods in a row" \
  --namespace AWS/EC2 --metric-name StatusCheckFailed --dimensions Name=InstanceId,Value="$IID" \
  --statistic Maximum --period 60 --evaluation-periods 2 --datapoints-to-alarm 2 \
  --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold --treat-missing-data missing

if [ "$HC" != "None" ] && [ -n "$HC" ]; then
  alarm health-check-down "Availability: Route 53 checkers report /health as unhealthy" \
    --namespace AWS/Route53 --metric-name HealthCheckStatus --dimensions Name=HealthCheckId,Value="$HC" \
    --statistic Minimum --period 60 --evaluation-periods 1 \
    --threshold 1 --comparison-operator LessThanThreshold --treat-missing-data breaching
else
  echo "WARNING: no Route 53 health check found, so the uptime alarm was skipped (see step 6)."
fi

aws cloudwatch describe-alarms --alarm-name-prefix "$ALARM_PREFIX" \
  --query 'MetricAlarms[].[AlarmName, StateValue, MetricName, Threshold]' --output table

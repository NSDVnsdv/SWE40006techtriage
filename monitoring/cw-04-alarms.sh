#!/bin/bash
# Below is the code to create the 7 Production alarms from Table 9 of the Project Brief. Each alarm emails the SNS topic
# when it fires and when it clears. Safe to re-run. Run it in CloudShell: bash cw-04-alarms.sh

# Below is the code to stop at the first error and load the shared settings from config.sh.
set -euo pipefail
source "$(dirname "$0")/config.sh"

# Below is the code to look up the server, the SNS topic, the health check and the disk metric,
# and stop with a clear message if an earlier step has not been done yet.
IID=$(instance_id); TOPIC=$(topic_arn); HC=$(health_check_id)
DISK_DIMS=$(disk_dimensions "$IID")
log "instance=$IID topic=$TOPIC healthcheck=$HC"
[ "$TOPIC" != "None" ] || { echo "Run cw-02-sns.sh first"; exit 1; }
[ "$DISK_DIMS" != "null" ] || { echo "No disk_used_percent metric yet: is the CloudWatch Agent running (step 3)?"; exit 1; }

# Below is the code to create (or update) one alarm. Its inputs are: the alarm name, a description,
# then the CloudWatch settings that decide when it fires. It always emails the team on ALARM and on OK.
alarm() {
  local name="${ALARM_PREFIX}-$1" desc="$2"; shift 2
  aws cloudwatch put-metric-alarm --alarm-name "$name" --alarm-description "$desc" \
    --alarm-actions "$TOPIC" --ok-actions "$TOPIC" "$@"
  log "alarm $name"
}

# Below is the code to create alarm 1: CPU average above 70% for 2 five-minute periods in a row.
alarm cpu-high "Saturation: CPU average above 70% for 2 x 5-minute periods" \
  --namespace AWS/EC2 --metric-name CPUUtilization --dimensions Name=InstanceId,Value="$IID" \
  --statistic Average --period 300 --evaluation-periods 2 --datapoints-to-alarm 2 \
  --threshold 70 --comparison-operator GreaterThanThreshold --treat-missing-data missing

# Below is the code to create alarm 2: memory used above 80% for 5 minutes (measured by the CloudWatch Agent).
alarm memory-high "Saturation: memory used above 80% for 5 minutes (CloudWatch Agent)" \
  --namespace "$NS" --metric-name mem_used_percent --dimensions Name=InstanceId,Value="$IID" \
  --statistic Average --period 60 --evaluation-periods 5 --datapoints-to-alarm 5 \
  --threshold 80 --comparison-operator GreaterThanThreshold --treat-missing-data missing

# Below is the code to create alarm 3: the main disk ("/") more than 80% full.
alarm disk-high "Saturation: root disk used above 80% (CloudWatch Agent)" \
  --namespace "$NS" --metric-name disk_used_percent --dimensions "$DISK_DIMS" \
  --statistic Average --period 60 --evaluation-periods 1 \
  --threshold 80 --comparison-operator GreaterThanThreshold --treat-missing-data missing

# Below is the code to create alarm 4: the slowest 5% of requests (p95) taking over 500 ms for 5 minutes.
alarm latency-p95-high "Latency: p95 response time above 500 ms for 5 minutes (access-log metric filter)" \
  --namespace "$NS" --metric-name RequestLatency \
  --extended-statistic p95 --period 60 --evaluation-periods 5 --datapoints-to-alarm 5 \
  --threshold 500 --comparison-operator GreaterThanThreshold --treat-missing-data notBreaching

# Below is the code to create alarm 5: more than 5 server errors (HTTP 5xx) within 5 minutes.
alarm http-5xx "Errors: more than 5 HTTP 5xx responses in 5 minutes (access-log metric filter)" \
  --namespace "$NS" --metric-name Http5xxCount \
  --statistic Sum --period 300 --evaluation-periods 1 \
  --threshold 5 --comparison-operator GreaterThanThreshold --treat-missing-data notBreaching

# Below is the code to create alarm 6: the EC2 status check failing for 2 minutes in a row.
alarm status-check-failed "Errors: EC2 status check failed for 2 periods in a row" \
  --namespace AWS/EC2 --metric-name StatusCheckFailed --dimensions Name=InstanceId,Value="$IID" \
  --statistic Maximum --period 60 --evaluation-periods 2 --datapoints-to-alarm 2 \
  --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold --treat-missing-data missing

# Below is the code to create alarm 7: the Route 53 checkers reporting /health as unhealthy.
# It is skipped with a warning if the health check (step 6) does not exist yet.
if [ "$HC" != "None" ] && [ -n "$HC" ]; then
  alarm health-check-down "Availability: Route 53 checkers report /health as unhealthy" \
    --namespace AWS/Route53 --metric-name HealthCheckStatus --dimensions Name=HealthCheckId,Value="$HC" \
    --statistic Minimum --period 60 --evaluation-periods 1 \
    --threshold 1 --comparison-operator LessThanThreshold --treat-missing-data breaching
else
  echo "WARNING: no Route 53 health check found, so the uptime alarm was skipped (see step 6)."
fi

# Below is the code to list every TechTriage alarm with its current state and threshold.
aws cloudwatch describe-alarms --alarm-name-prefix "$ALARM_PREFIX" \
  --query 'MetricAlarms[].[AlarmName, StateValue, MetricName, Threshold]' --output table

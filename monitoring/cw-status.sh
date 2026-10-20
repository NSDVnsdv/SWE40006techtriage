#!/bin/bash
# Evidence helper. Run in CloudShell:  bash cw-status.sh
# Prints every alarm's current state and its state changes from the last
# 24 hours (UTC). Use the ALARM timestamps against the alarm-test START times
# and the email arrival times to measure "threshold crossed -> email" (<= 5 min).
set -euo pipefail
source "$(dirname "$0")/config.sh"

echo "== Current alarm states"
aws cloudwatch describe-alarms --alarm-name-prefix "$ALARM_PREFIX" \
  --query 'MetricAlarms[].[AlarmName, StateValue, StateUpdatedTimestamp]' --output table

echo "== State changes in the last 24 hours"
# describe-alarm-history has no name-prefix option, so filter in the query instead.
aws cloudwatch describe-alarm-history \
  --history-item-type StateUpdate --start-date "$(date -u -d '-24 hours' +%FT%TZ)" \
  --query "reverse(sort_by(AlarmHistoryItems[?starts_with(AlarmName, '${ALARM_PREFIX}')], &Timestamp))[].[Timestamp, AlarmName, HistorySummary]" \
  --output table

echo "== SNS subscriptions"
TOPIC=$(topic_arn)
[ "$TOPIC" = "None" ] || aws sns list-subscriptions-by-topic --topic-arn "$TOPIC" \
  --query 'Subscriptions[].[Endpoint, SubscriptionArn]' --output table

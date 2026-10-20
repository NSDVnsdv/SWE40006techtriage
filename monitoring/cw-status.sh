#!/bin/bash
# Below is the code to print every alarm's current state and its changes over the last 24 hours (UTC), to compare
# against the alarm-test start times and email arrival times (target: 5 minutes or less). Run: bash cw-status.sh

# Below is the code to stop at the first error and load the shared settings from config.sh.
set -euo pipefail
source "$(dirname "$0")/config.sh"

# Below is the code to show each alarm's current state and when it last changed.
echo "== Current alarm states"
aws cloudwatch describe-alarms --alarm-name-prefix "$ALARM_PREFIX" \
  --query 'MetricAlarms[].[AlarmName, StateValue, StateUpdatedTimestamp]' --output table

# Below is the code to show every alarm state change from the last 24 hours, newest first. The history command has no
# name-prefix option, so the TechTriage alarms are picked out inside the query instead.
echo "== State changes in the last 24 hours"
aws cloudwatch describe-alarm-history \
  --history-item-type StateUpdate --start-date "$(date -u -d '-24 hours' +%FT%TZ)" \
  --query "reverse(sort_by(AlarmHistoryItems[?starts_with(AlarmName, '${ALARM_PREFIX}')], &Timestamp))[].[Timestamp, AlarmName, HistorySummary]" \
  --output table

# Below is the code to list the email subscriptions on the SNS topic, if the topic exists.
echo "== SNS subscriptions"
TOPIC=$(topic_arn)
[ "$TOPIC" = "None" ] || aws sns list-subscriptions-by-topic --topic-arn "$TOPIC" \
  --query 'Subscriptions[].[Endpoint, SubscriptionArn]' --output table

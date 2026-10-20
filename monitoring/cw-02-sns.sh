#!/bin/bash
# Below is the code to create the SNS topic that emails alarms to the team, and subscribe every member's email. Run it in
# CloudShell: bash cw-02-sns.sh email1 email2 ... (each person must click "Confirm subscription" in the AWS email).

# Below is the code to stop at the first error, load config.sh, and insist on at least one email address.
set -euo pipefail
source "$(dirname "$0")/config.sh"
[ $# -ge 1 ] || { echo "usage: $0 email [email ...]"; exit 1; }

# Below is the code to create the topic (or reuse it if it already exists) and send a subscription request to each email.
ARN=$(aws sns create-topic --name "$TOPIC_NAME" --tags Key=Project,Value=techtriage --query TopicArn --output text)
log "SNS topic: $ARN"
for e in "$@"; do
  aws sns subscribe --topic-arn "$ARN" --protocol email --notification-endpoint "$e" >/dev/null
  log "subscription request sent to $e"
done

# Below is the code to list the subscriptions, and print the command for sending a test email once everyone has confirmed.
aws sns list-subscriptions-by-topic --topic-arn "$ARN" \
  --query 'Subscriptions[].[Endpoint, SubscriptionArn]' --output table
echo "Re-run the line above after everyone confirms: PendingConfirmation should become a full ARN."
echo "Send a test message:"
echo "  aws sns publish --topic-arn $ARN --subject 'TechTriage SNS test' --message 'Test from CloudShell $(date -u +%FT%TZ)'"

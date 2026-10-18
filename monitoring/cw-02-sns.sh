#!/bin/bash
# Level 2, step 5. Run in CloudShell with every team member's email:
#   bash cw-02-sns.sh a@student.swin.edu.au b@student.swin.edu.au ...
# Each person must click "Confirm subscription" in the email from AWS.
set -euo pipefail
source "$(dirname "$0")/config.sh"
[ $# -ge 1 ] || { echo "usage: $0 email [email ...]"; exit 1; }

ARN=$(aws sns create-topic --name "$TOPIC_NAME" --tags Key=Project,Value=techtriage --query TopicArn --output text)
log "SNS topic: $ARN"
for e in "$@"; do
  aws sns subscribe --topic-arn "$ARN" --protocol email --notification-endpoint "$e" >/dev/null
  log "subscription request sent to $e"
done
aws sns list-subscriptions-by-topic --topic-arn "$ARN" \
  --query 'Subscriptions[].[Endpoint, SubscriptionArn]' --output table
echo "Re-run the line above after everyone confirms: PendingConfirmation should become a full ARN."
echo "Send a test message:"
echo "  aws sns publish --topic-arn $ARN --subject 'TechTriage SNS test' --message 'Test from CloudShell $(date -u +%FT%TZ)'"

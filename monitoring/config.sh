#!/bin/bash
# shellcheck disable=SC2034
# Below is the code to hold the shared settings for the Level 2 CloudShell scripts (cw-*.sh, alarm-test-cloudshell.sh).
# Those scripts load it with "source". Nothing here is secret, because everything is looked up by its tag.

# Below is the code to use the us-east-1 AWS region unless another region is already set.
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
REGION="$AWS_DEFAULT_REGION"

# Below is the code to name the Production resources: the server's Name tag, its Elastic IP, the custom metric
# namespace, the app's log group, the SNS email topic, the alarm name prefix and the dashboard name.
PROD_NAME_TAG="techtriage-production"
PROD_IP="3.232.71.71"
NS="TechTriage/Production"
APP_LOG_GROUP="/techtriage/production/app"
TOPIC_NAME="techtriage-production-alerts"
ALARM_PREFIX="techtriage-prod"
DASHBOARD_NAME="TechTriage-Production"

# Below is the code to print a message with the current UTC time in front of it.
log() { echo "$(date -u +%FT%TZ) $*"; }

# Below is the code to look up the Production server's instance ID from its Name tag.
instance_id() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${PROD_NAME_TAG}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text
}

# Below is the code to look up the ID of a server's disk (its EBS volume), used for the disk I/O graph.
volume_id() {
  aws ec2 describe-instances --instance-ids "$1" \
    --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' --output text
}

# Below is the code to look up the SNS topic that emails the team.
topic_arn() {
  aws sns list-topics --query "Topics[?ends_with(TopicArn, ':${TOPIC_NAME}')].TopicArn | [0]" --output text
}

# Below is the code to find the Route 53 health check that calls Production's /health ("None" if it does not exist yet).
health_check_id() {
  aws route53 list-health-checks \
    --query "HealthChecks[?HealthCheckConfig.IPAddress=='${PROD_IP}' && HealthCheckConfig.ResourcePath=='/health'].Id | [0]" \
    --output text 2>/dev/null || echo None
}

# Below is the code to get the labels (dimensions) the CloudWatch Agent puts on the "disk used %" metric for "/",
# as a JSON list.
disk_dimensions() {
  aws cloudwatch list-metrics --namespace "$NS" --metric-name disk_used_percent \
    --dimensions "Name=InstanceId,Value=$1" "Name=path,Value=/" \
    --query 'Metrics[0].Dimensions' --output json
}

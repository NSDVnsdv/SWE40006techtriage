#!/bin/bash
# shellcheck disable=SC2034  # variables are used by the scripts that source this file
# Shared settings for the Level 2 CloudShell scripts (cw-*.sh, alarm-test-cloudshell.sh).
# Sourced, not run. Everything is looked up by tag, so nothing here is secret.

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
REGION="$AWS_DEFAULT_REGION"

PROD_NAME_TAG="techtriage-production"
PROD_IP="3.232.71.71"                       # Production Elastic IP (Level 1, step 17)
NS="TechTriage/Production"                  # CloudWatch namespace for our custom metrics
APP_LOG_GROUP="/techtriage/production/app"  # app container logs (compose.monitoring.yaml)
TOPIC_NAME="techtriage-production-alerts"   # SNS topic for alarm emails
ALARM_PREFIX="techtriage-prod"
DASHBOARD_NAME="TechTriage-Production"

log() { echo "$(date -u +%FT%TZ) $*"; }

instance_id() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${PROD_NAME_TAG}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text
}

volume_id() {
  aws ec2 describe-instances --instance-ids "$1" \
    --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' --output text
}

topic_arn() {
  aws sns list-topics --query "Topics[?ends_with(TopicArn, ':${TOPIC_NAME}')].TopicArn | [0]" --output text
}

# Route 53 health check pointing at Production /health ("None" if not created).
health_check_id() {
  aws route53 list-health-checks \
    --query "HealthChecks[?HealthCheckConfig.IPAddress=='${PROD_IP}' && HealthCheckConfig.ResourcePath=='/health'].Id | [0]" \
    --output text 2>/dev/null || echo None
}

# Dimensions the CloudWatch Agent uses for disk_used_percent on "/" (JSON list).
disk_dimensions() {
  aws cloudwatch list-metrics --namespace "$NS" --metric-name disk_used_percent \
    --dimensions "Name=InstanceId,Value=$1" "Name=path,Value=/" \
    --query 'Metrics[0].Dimensions' --output json
}

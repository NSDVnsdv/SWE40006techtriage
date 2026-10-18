#!/bin/bash
# Level 2, step 6. Run in CloudShell:  bash cw-03-health-check.sh
# Creates a Route 53 health check that requests http://<Production EIP>/health
# from AWS checkers around the world every 30 seconds (outside-in uptime check).
set -euo pipefail
source "$(dirname "$0")/config.sh"

HC=$(health_check_id)
if [ "$HC" = "None" ] || [ -z "$HC" ]; then
  HC=$(aws route53 create-health-check --caller-reference "techtriage-prod-$(date +%s)" \
    --health-check-config "IPAddress=${PROD_IP},Port=80,Type=HTTP,ResourcePath=/health,RequestInterval=30,FailureThreshold=3" \
    --query 'HealthCheck.Id' --output text)
  aws route53 change-tags-for-resource --resource-type healthcheck --resource-id "$HC" \
    --add-tags Key=Name,Value=techtriage-production-health
  log "created health check $HC"
else
  log "health check already exists: $HC"
fi
aws route53 get-health-check --health-check-id "$HC" --query 'HealthCheck.HealthCheckConfig' --output table
log "Checker results (wait ~1 min after creating; expect 'Success: HTTP Status Code 200'):"
aws route53 get-health-check-status --health-check-id "$HC" \
  --query 'HealthCheckObservations[].[Region, StatusReport.Status]' --output table

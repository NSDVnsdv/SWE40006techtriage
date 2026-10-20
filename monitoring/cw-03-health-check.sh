#!/bin/bash
# Below is the code to create a Route 53 health check that calls http://<Production Elastic IP>/health every 30 seconds
# from AWS checkers around the world (an uptime check from outside AWS). Run it in CloudShell: bash cw-03-health-check.sh

# Below is the code to stop at the first error and load the shared settings from config.sh.
set -euo pipefail
source "$(dirname "$0")/config.sh"

# Below is the code to create the health check and give it a name, but only if it does not exist yet.
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

# Below is the code to show the health check's settings and what each checker around the world currently sees.
aws route53 get-health-check --health-check-id "$HC" --query 'HealthCheck.HealthCheckConfig' --output table
log "Checker results (wait ~1 min after creating; expect 'Success: HTTP Status Code 200'):"
aws route53 get-health-check-status --health-check-id "$HC" \
  --query 'HealthCheckObservations[].[Region, StatusReport.Status]' --output table

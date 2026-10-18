#!/bin/bash
# Level 2, step 2. Run ON PRODUCTION as root (Session Manager, after `sudo -i`):
#   curl -fsSL https://raw.githubusercontent.com/NSDVnsdv/SWE40006techtriage/main/monitoring/prod-enable-logging.sh | bash
#
# Pulls the newest compose files and image, switches on compose.monitoring.yaml
# (container logs -> CloudWatch Logs) and copies the other Production scripts
# to /opt/techtriage/monitoring.
set -euo pipefail

REF="${REF:-main}"
RAW="https://raw.githubusercontent.com/NSDVnsdv/SWE40006techtriage/${REF}"
APP_DIR="/opt/techtriage"

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo -i first"; exit 1; }
grep -q '^APP_ENV=production$' "$APP_DIR/.env" || { echo "This is not the production server, stopping."; exit 1; }

# Set KEY=VALUE in .env, replacing the line if it already exists.
set_env() {
  if grep -q "^$1=" "$APP_DIR/.env"; then sed -i "s|^$1=.*|$1=$2|" "$APP_DIR/.env"
  else echo "$1=$2" >> "$APP_DIR/.env"; fi
}

echo "== 1. Download compose files and Production scripts from ${REF}"
curl -fsSL "$RAW/compose.yaml"            -o "$APP_DIR/compose.yaml"
curl -fsSL "$RAW/compose.monitoring.yaml" -o "$APP_DIR/compose.monitoring.yaml"
mkdir -p "$APP_DIR/monitoring"
for f in prod-install-agent.sh prod-fault-injection.sh alarm-test-prod.sh cloudwatch-agent.json; do
  curl -fsSL "$RAW/monitoring/$f" -o "$APP_DIR/monitoring/$f"
done
chmod +x "$APP_DIR"/monitoring/*.sh

echo "== 2. Switch on the monitoring override in .env"
set_env COMPOSE_FILE "compose.yaml:compose.monitoring.yaml"
set_env AWS_REGION "us-east-1"
set_env FAULT_INJECTION "0"
cat "$APP_DIR/.env"

echo "== 3. Pull the newest image and recreate the app"
cd "$APP_DIR"
docker compose pull
docker compose up -d
sleep 15
docker compose ps

echo "== 4. Checks"
echo -n "Logging driver: "; docker inspect techtriage-app-1 --format '{{.HostConfig.LogConfig.Type}} {{json .HostConfig.LogConfig.Config}}'
for p in / /version /health /does-not-exist; do
  echo "GET $p -> $(curl -s -o /dev/null -w '%{http_code}' "http://localhost$p")"
done
curl -s localhost/version; echo
echo "Last log lines (these are also in CloudWatch Logs group /techtriage/production/app):"
docker compose logs --tail 6 app

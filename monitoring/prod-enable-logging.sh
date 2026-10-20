#!/bin/bash
# Below is the code to switch on CloudWatch logging on Production: download the compose files and Production scripts,
# update .env and restart the app. Run ON PRODUCTION as root: curl -fsSL <raw GitHub link to this file> | bash

# Below is the code to stop the script at the first error.
set -euo pipefail

# Below is the code to say which branch to download from (main unless REF is set) and where the app lives on the server.
REF="${REF:-main}"
RAW="https://raw.githubusercontent.com/NSDVnsdv/SWE40006techtriage/${REF}"
APP_DIR="/opt/techtriage"

# Below is the code to stop unless the script is running as root on the Production server.
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo -i first"; exit 1; }
grep -q '^APP_ENV=production$' "$APP_DIR/.env" || { echo "This is not the production server, stopping."; exit 1; }

# Below is the code to set KEY=VALUE in .env, replacing the line if it already exists or adding it if not.
set_env() {
  if grep -q "^$1=" "$APP_DIR/.env"; then sed -i "s|^$1=.*|$1=$2|" "$APP_DIR/.env"
  else echo "$1=$2" >> "$APP_DIR/.env"; fi
}

# Below is the code to download both compose files and the other Production monitoring scripts.
echo "== 1. Download compose files and Production scripts from ${REF}"
curl -fsSL "$RAW/compose.yaml"            -o "$APP_DIR/compose.yaml"
curl -fsSL "$RAW/compose.monitoring.yaml" -o "$APP_DIR/compose.monitoring.yaml"
mkdir -p "$APP_DIR/monitoring"
for f in prod-install-agent.sh prod-fault-injection.sh alarm-test-prod.sh cloudwatch-agent.json; do
  curl -fsSL "$RAW/monitoring/$f" -o "$APP_DIR/monitoring/$f"
done
chmod +x "$APP_DIR"/monitoring/*.sh

# Below is the code to switch on the monitoring add-on in .env, with the fault test pages kept off.
echo "== 2. Switch on the monitoring override in .env"
set_env COMPOSE_FILE "compose.yaml:compose.monitoring.yaml"
set_env AWS_REGION "us-east-1"
set_env FAULT_INJECTION "0"
cat "$APP_DIR/.env"

# Below is the code to download the newest image and recreate the app with the new settings.
echo "== 3. Pull the newest image and recreate the app"
cd "$APP_DIR"
docker compose pull
docker compose up -d
sleep 15
docker compose ps

# Below is the code to check the result: the logging driver in use, the answer from each page, and the latest log lines.
echo "== 4. Checks"
echo -n "Logging driver: "; docker inspect techtriage-app-1 --format '{{.HostConfig.LogConfig.Type}} {{json .HostConfig.LogConfig.Config}}'
for p in / /version /health /does-not-exist; do
  echo "GET $p -> $(curl -s -o /dev/null -w '%{http_code}' "http://localhost$p")"
done
curl -s localhost/version; echo
echo "Last log lines (these are also in CloudWatch Logs group /techtriage/production/app):"
docker compose logs --tail 6 app

#!/bin/bash
# Below is the code to turn the test-only /_fault pages on or off on PRODUCTION (run as root): use "on" just before
# the latency and 5xx alarm tests and "off" straight after. Run: bash /opt/techtriage/monitoring/prod-fault-injection.sh on|off

# Below is the code to stop the script at the first error.
set -euo pipefail

# Below is the code to stop unless running as root, and turn the word "on" or "off" into 1 or 0.
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo -i first"; exit 1; }
case "${1:-}" in on) v=1 ;; off) v=0 ;; *) echo "usage: $0 on|off"; exit 1 ;; esac

# Below is the code to save the new setting in .env (adding the line if it is missing) and restart the app with it.
cd /opt/techtriage
sed -i "s|^FAULT_INJECTION=.*|FAULT_INJECTION=$v|" .env
grep -q '^FAULT_INJECTION=' .env || echo "FAULT_INJECTION=$v" >> .env
docker compose up -d
sleep 10

# Below is the code to record the change in the monitoring log and check the test page now answers as expected.
echo "$(date -u +%FT%TZ) [fault-injection] $1" | tee -a /var/log/techtriage-monitoring.log
echo "GET /_fault/500 -> $(curl -s -o /dev/null -w '%{http_code}' localhost/_fault/500)  (expect 500 when on, 404 when off)"

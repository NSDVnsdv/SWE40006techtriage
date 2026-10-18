#!/bin/bash
# Turns the test-only /_fault routes on or off on PRODUCTION (run as root).
#   bash /opt/techtriage/monitoring/prod-fault-injection.sh on    # before latency/5xx alarm tests
#   bash /opt/techtriage/monitoring/prod-fault-injection.sh off   # straight after
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo -i first"; exit 1; }
case "${1:-}" in on) v=1 ;; off) v=0 ;; *) echo "usage: $0 on|off"; exit 1 ;; esac

cd /opt/techtriage
sed -i "s|^FAULT_INJECTION=.*|FAULT_INJECTION=$v|" .env
grep -q '^FAULT_INJECTION=' .env || echo "FAULT_INJECTION=$v" >> .env
docker compose up -d
sleep 10
echo "$(date -u +%FT%TZ) [fault-injection] $1" | tee -a /var/log/techtriage-monitoring.log
echo "GET /_fault/500 -> $(curl -s -o /dev/null -w '%{http_code}' localhost/_fault/500)  (expect 500 when on, 404 when off)"

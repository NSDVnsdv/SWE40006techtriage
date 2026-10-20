#!/usr/bin/env bash
# Below is the code to call <url>/health every 10 seconds, for up to 3 minutes, until it says the database is connected.
# Usage: bash scripts/wait-for-health.sh http://<server address>
set -uo pipefail
url="$1"
for attempt in $(seq 1 18); do
  body=$(curl -s --max-time 5 "$url/health" || true)
  echo "$(date -u +%H:%M:%S) attempt $attempt: ${body:-no answer yet}"
  if echo "$body" | grep -q '"database": *"connected"'; then exit 0; fi
  sleep 10
done
echo "::error::$url/health never reported the database as connected"
exit 1

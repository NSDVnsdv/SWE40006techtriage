#!/bin/bash
# Level 2, step 9. Real alarm triggers that run ON PRODUCTION (as root).
# Every test runs in the background and undoes itself, so closing the
# Session Manager window is safe. Start/end times go to
# /var/log/techtriage-monitoring.log, which the agent ships to CloudWatch Logs
# (/techtriage/production/monitoring) as timing evidence.
#
#   bash alarm-test-prod.sh cpu        # ~100% CPU for 15 min   -> cpu-high (needs 2 x 5-min periods)
#   bash alarm-test-prod.sh memory     # hold RAM at ~90% for 7 min -> memory-high
#   bash alarm-test-prod.sh disk       # fill "/" to ~86% for 10 min -> disk-high
#   bash alarm-test-prod.sh downtime   # stop the app for 5 min -> health-check-down
#   bash alarm-test-prod.sh status     # current CPU / RAM / disk / container state
#   bash alarm-test-prod.sh cleanup    # stop every test now
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo -i first"; exit 1; }

LOG=/var/log/techtriage-monitoring.log
FILL=/var/tmp/techtriage-diskfill.bin
note() { echo "$(date -u +%FT%TZ) [alarm-test] $*" | tee -a "$LOG"; }

case "${1:-}" in
  cpu)
    for _ in $(seq "$(nproc)"); do nohup timeout 900 yes >/dev/null 2>&1 & done
    note "cpu: START - $(nproc) busy loops for 15 min (auto-stop)"
    nohup sh -c "sleep 900; echo \"\$(date -u +%FT%TZ) [alarm-test] cpu: END\" >> $LOG" >/dev/null 2>&1 &
    ;;
  memory)
    total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    need_kb=$(( total * 90 / 100 - (total - avail) ))
    [ "$need_kb" -gt 0 ] || { note "memory: already above 90%, nothing to do"; exit 0; }
    note "memory: START - holding $(( need_kb / 1024 )) MiB for 7 min (target ~90% used)"
    nohup python3 -c "
import time
block = bytes([1]) * ($need_kb * 1024)   # filled bytes, so the pages are really used
time.sleep(420)
" >/dev/null 2>&1 &
    nohup sh -c "sleep 425; echo \"\$(date -u +%FT%TZ) [alarm-test] memory: END\" >> $LOG" >/dev/null 2>&1 &
    ;;
  disk)
    read -r size used <<<"$(df -B1 --output=size,used / | tail -1)"
    need=$(( size * 86 / 100 - used ))
    [ "$need" -gt 0 ] || { note "disk: already above 86%, nothing to do"; exit 0; }
    fallocate -l "$need" "$FILL"
    note "disk: START - wrote $(( need / 1024 / 1024 )) MiB to $FILL, $(df --output=pcent / | tail -1 | tr -d ' ') used, auto-delete in 10 min"
    nohup sh -c "sleep 600; rm -f $FILL; echo \"\$(date -u +%FT%TZ) [alarm-test] disk: END - file deleted\" >> $LOG" >/dev/null 2>&1 &
    ;;
  downtime)
    cd /opt/techtriage
    docker compose stop app
    note "downtime: START - app container stopped, auto-start in 5 min"
    nohup sh -c "sleep 300; cd /opt/techtriage && docker compose start app; echo \"\$(date -u +%FT%TZ) [alarm-test] downtime: END - app started\" >> $LOG" >/dev/null 2>&1 &
    ;;
  cleanup)
    pkill -x yes || true
    pkill -f "block = bytes" || true
    rm -f "$FILL"
    (cd /opt/techtriage && docker compose start app)
    note "cleanup: all tests stopped"
    ;;
  status)
    echo "--- CPU (top)";   top -bn1 | head -5
    echo "--- Memory";      free -m
    echo "--- Disk /";      df -h /
    echo "--- App";         (cd /opt/techtriage && docker compose ps)
    echo "--- Test log";    tail -n 15 "$LOG"
    ;;
  *) sed -n '2,15p' "$0"; exit 1 ;;
esac

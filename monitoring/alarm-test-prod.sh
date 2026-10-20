#!/bin/bash
# Below is the code to run real alarm triggers ON PRODUCTION (as root). Each test runs in the background and undoes itself,
# and its start and end times go to /var/log/techtriage-monitoring.log, which the agent ships to CloudWatch Logs as evidence.

# Below is the code to stop at the first error, and stop unless running as root.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo -i first"; exit 1; }

# Below is the code to name the test log and the temporary disk-filling file, and a helper that writes timed notes to the log.
LOG=/var/log/techtriage-monitoring.log
FILL=/var/tmp/techtriage-diskfill.bin
note() { echo "$(date -u +%FT%TZ) [alarm-test] $*" | tee -a "$LOG"; }

# Below is the code to print how to use this script (shown when it is run without a valid test name).
usage() {
  echo "Level 2, step 9. Real alarm triggers that run ON PRODUCTION (as root). Each test undoes itself:"
  echo "  bash alarm-test-prod.sh cpu        -> about 100% CPU for 15 min, fires cpu-high (needs 2 x 5-min periods)"
  echo "  bash alarm-test-prod.sh memory     -> hold RAM at about 90% for 7 min, fires memory-high"
  echo "  bash alarm-test-prod.sh disk       -> fill the / disk to about 86% for 10 min, fires disk-high"
  echo "  bash alarm-test-prod.sh downtime   -> stop the app for 5 min, fires health-check-down"
  echo "  bash alarm-test-prod.sh status     -> current CPU / RAM / disk / container state"
  echo "  bash alarm-test-prod.sh cleanup    -> stop every test now"
}

# Below is the code to run the test named on the command line.
case "${1:-}" in
  # Below is the code to keep every CPU core 100% busy for 15 minutes (it stops by itself), to fire cpu-high.
  cpu)
    for _ in $(seq "$(nproc)"); do nohup timeout 900 yes >/dev/null 2>&1 & done
    note "cpu: START - $(nproc) busy loops for 15 min (auto-stop)"
    nohup sh -c "sleep 900; echo \"\$(date -u +%FT%TZ) [alarm-test] cpu: END\" >> $LOG" >/dev/null 2>&1 &
    ;;
  # Below is the code to hold enough memory to reach about 90% used for 7 minutes, to fire memory-high.
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
  # Below is the code to fill the main disk to about 86% with a temporary file that deletes itself after 10 minutes,
  # to fire disk-high.
  disk)
    read -r size used <<<"$(df -B1 --output=size,used / | tail -1)"
    need=$(( size * 86 / 100 - used ))
    [ "$need" -gt 0 ] || { note "disk: already above 86%, nothing to do"; exit 0; }
    fallocate -l "$need" "$FILL"
    note "disk: START - wrote $(( need / 1024 / 1024 )) MiB to $FILL, $(df --output=pcent / | tail -1 | tr -d ' ') used, auto-delete in 10 min"
    nohup sh -c "sleep 600; rm -f $FILL; echo \"\$(date -u +%FT%TZ) [alarm-test] disk: END - file deleted\" >> $LOG" >/dev/null 2>&1 &
    ;;
  # Below is the code to stop the app for 5 minutes (it starts again by itself), to fire health-check-down.
  downtime)
    cd /opt/techtriage
    docker compose stop app
    note "downtime: START - app container stopped, auto-start in 5 min"
    nohup sh -c "sleep 300; cd /opt/techtriage && docker compose start app; echo \"\$(date -u +%FT%TZ) [alarm-test] downtime: END - app started\" >> $LOG" >/dev/null 2>&1 &
    ;;
  # Below is the code to stop every running test straight away and make sure the app is running again.
  cleanup)
    pkill -x yes || true
    pkill -f "block = bytes" || true
    rm -f "$FILL"
    (cd /opt/techtriage && docker compose start app)
    note "cleanup: all tests stopped"
    ;;
  # Below is the code to show the current CPU, memory, disk and app state, plus the latest test log lines.
  status)
    echo "--- CPU (top)";   top -bn1 | head -5
    echo "--- Memory";      free -m
    echo "--- Disk /";      df -h /
    echo "--- App";         (cd /opt/techtriage && docker compose ps)
    echo "--- Test log";    tail -n 15 "$LOG"
    ;;
  # Below is the code to show the usage help for anything else.
  *) usage; exit 1 ;;
esac

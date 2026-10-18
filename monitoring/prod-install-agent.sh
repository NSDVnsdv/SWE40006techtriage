#!/bin/bash
# Level 2, step 3. Run ON PRODUCTION as root:
#   bash /opt/techtriage/monitoring/prod-install-agent.sh
# Installs the CloudWatch Agent and starts it with monitoring/cloudwatch-agent.json
# (memory %, disk % for "/", and the setup/monitoring log files).
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo -i first"; exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"
CTL=/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl
CONF=/opt/aws/amazon-cloudwatch-agent/etc/techtriage.json

echo "== 1. Install the agent"
dnf install -y amazon-cloudwatch-agent
rpm -q amazon-cloudwatch-agent

echo "== 2. Install our config"
cp "$HERE/cloudwatch-agent.json" "$CONF"
touch /var/log/techtriage-monitoring.log
cat "$CONF"

echo "== 3. Load the config and start the agent"
"$CTL" -a fetch-config -m ec2 -s -c "file:$CONF"
sleep 5
"$CTL" -m ec2 -a status
systemctl is-enabled amazon-cloudwatch-agent

echo "$(date -u +%FT%TZ) [setup] CloudWatch Agent installed and started" >> /var/log/techtriage-monitoring.log
echo "== 4. Agent log (should show no errors)"
tail -n 15 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log

#!/bin/bash
# Below is the code to install the CloudWatch Agent on PRODUCTION and start it with monitoring/cloudwatch-agent.json, which collects
# memory % and disk % for "/" every 60 seconds and ships the setup and monitoring log files. Run as root on Production.

# Below is the code to stop the script at the first error.
set -euo pipefail

# Below is the code to stop unless running as root, and name the folders and files the agent uses.
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo -i first"; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
CTL=/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl
CONF=/opt/aws/amazon-cloudwatch-agent/etc/techtriage.json

# Below is the code to install the agent and show the installed version.
echo "== 1. Install the agent"
dnf install -y amazon-cloudwatch-agent
rpm -q amazon-cloudwatch-agent

# Below is the code to copy our agent settings into place and create the monitoring log file it watches.
echo "== 2. Install our config"
cp "$HERE/cloudwatch-agent.json" "$CONF"
touch /var/log/techtriage-monitoring.log
cat "$CONF"

# Below is the code to load the settings, start the agent, and check it is running and starts on every boot.
echo "== 3. Load the config and start the agent"
"$CTL" -a fetch-config -m ec2 -s -c "file:$CONF"
sleep 5
"$CTL" -m ec2 -a status
systemctl is-enabled amazon-cloudwatch-agent

# Below is the code to record the install in the monitoring log and show the agent's own log, which should have no errors.
echo "$(date -u +%FT%TZ) [setup] CloudWatch Agent installed and started" >> /var/log/techtriage-monitoring.log
echo "== 4. Agent log (should show no errors)"
tail -n 15 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log

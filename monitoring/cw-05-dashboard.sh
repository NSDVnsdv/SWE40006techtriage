#!/bin/bash
# Level 2, step 8. Run in CloudShell:  bash cw-05-dashboard.sh
# Builds the "TechTriage-Production" CloudWatch dashboard: CPU, memory, disk,
# disk I/O, network, requests, latency, 5xx, status checks, uptime, alarm
# status and a live tail of the access log. Safe to re-run (overwrites it).
set -euo pipefail
source "$(dirname "$0")/config.sh"

IID=$(instance_id); VOL=$(volume_id "$IID"); HC=$(health_check_id)
DISK_DIMS=$(disk_dimensions "$IID")
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
log "instance=$IID volume=$VOL healthcheck=$HC"
export IID VOL HC DISK_DIMS ACCOUNT REGION NS
LOGS="$APP_LOG_GROUP" PREFIX="$ALARM_PREFIX" python3 - > /tmp/techtriage-dashboard.json <<'PY'
import json, os
e = os.environ
iid, vol, hc, ns, region = e["IID"], e["VOL"], e["HC"], e["NS"], e["REGION"]
disk = json.loads(e["DISK_DIMS"]) or []
disk_metric = [ns, "disk_used_percent"] + [x for d in disk for x in (d["Name"], d["Value"])]

def metric(title, metrics, x, y, w=8, h=6, stat="Average", period=60, ymax=None, line=None):
    p = {"title": title, "region": region, "view": "timeSeries", "stacked": False,
         "stat": stat, "period": period, "metrics": metrics}
    if ymax: p["yAxis"] = {"left": {"min": 0, "max": ymax}}
    if line: p["annotations"] = {"horizontal": [{"label": line[0], "value": line[1], "color": "#d62728"}]}
    return {"type": "metric", "x": x, "y": y, "width": w, "height": h, "properties": p}

alarms = ["cpu-high", "memory-high", "disk-high", "latency-p95-high", "http-5xx",
          "status-check-failed"] + (["health-check-down"] if hc not in ("", "None") else [])
widgets = [
    {"type": "text", "x": 0, "y": 0, "width": 24, "height": 2, "properties": {"markdown":
        f"## TechTriage - Production monitoring\nInstance `{iid}` · Elastic IP `3.232.71.71` · "
        "Golden signals: saturation (CPU, memory, disk), traffic, latency, errors · alarms email the team through SNS"}},
    metric("CPU utilisation (%)", [["AWS/EC2", "CPUUtilization", "InstanceId", iid]], 0, 2, period=300, ymax=100, line=("Alarm 70%", 70)),
    metric("Memory used (%)", [[ns, "mem_used_percent", "InstanceId", iid]], 8, 2, ymax=100, line=("Alarm 80%", 80)),
    metric("Root disk used (%)", [disk_metric], 16, 2, ymax=100, line=("Alarm 80%", 80)),
    metric("Network traffic (bytes per 5 min)", [["AWS/EC2", "NetworkIn", "InstanceId", iid, {"label": "In"}],
                                                 ["AWS/EC2", "NetworkOut", "InstanceId", iid, {"label": "Out"}]], 0, 8, stat="Sum", period=300),
    metric("Disk I/O (bytes per min, EBS)", [["AWS/EBS", "VolumeReadBytes", "VolumeId", vol, {"label": "Read"}],
                                             ["AWS/EBS", "VolumeWriteBytes", "VolumeId", vol, {"label": "Write"}]], 8, 8, stat="Sum"),
    metric("Requests per minute", [[ns, "RequestCount"]], 16, 8, stat="Sum"),
    metric("HTTP request latency (ms)", [[ns, "RequestLatency", {"stat": "p50", "label": "p50"}],
                                         [ns, "RequestLatency", {"stat": "p95", "label": "p95"}]], 0, 14, line=("Alarm p95 500 ms", 500)),
    metric("HTTP 5xx errors (per min)", [[ns, "Http5xxCount"]], 8, 14, stat="Sum"),
    metric("EC2 status check failed (0 = OK)", [["AWS/EC2", "StatusCheckFailed", "InstanceId", iid]], 16, 14, stat="Maximum"),
]
if hc not in ("", "None"):
    widgets.append(metric("Uptime: Route 53 /health check (1 = healthy)",
                          [["AWS/Route53", "HealthCheckStatus", "HealthCheckId", hc]], 0, 20, stat="Minimum", ymax=1))
widgets.append({"type": "alarm", "x": 8, "y": 20, "width": 16, "height": 6, "properties": {
    "title": "Alarm status",
    "alarms": [f"arn:aws:cloudwatch:{region}:{e['ACCOUNT']}:alarm:{e['PREFIX']}-{a}" for a in alarms]}})
widgets.append({"type": "log", "x": 0, "y": 26, "width": 24, "height": 6, "properties": {
    "title": "Latest requests (access log)", "region": region, "view": "table",
    "query": f"SOURCE '{e['LOGS']}' | fields @timestamp, method, path, status, duration_ms "
             "| filter type = 'access' | sort @timestamp desc | limit 20"}})
print(json.dumps({"start": "-PT3H", "periodOverride": "inherit", "widgets": widgets}))
PY

aws cloudwatch put-dashboard --dashboard-name "$DASHBOARD_NAME" --dashboard-body file:///tmp/techtriage-dashboard.json
log "Dashboard: https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#dashboards/dashboard/${DASHBOARD_NAME}"

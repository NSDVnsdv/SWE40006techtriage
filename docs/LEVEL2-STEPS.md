# Level 2 runbook: Production instrumentation and monitoring

Every Level 2 step in order, with exact commands and what to capture. Brackets
like (11.3) are Table 10 steps in the Project Brief; alarm thresholds come from
Table 9.

**For every step: take a screenshot AND copy the terminal/log text.** If
anything breaks, write it in [error-log.md](error-log.md) straight away.

Legend: `[x]` done, `[ ]` to do.

---

## How the monitoring fits together

```
Production EC2 (i-05fa5eb69c835d120, 3.232.71.71)
 ├─ EC2 built-in metrics ───────────────── CPU, network, status checks ──┐
 ├─ EBS volume metrics ─────────────────── disk read/write bytes ────────┤
 ├─ CloudWatch Agent ───────────────────── memory %, disk % ─────────────┤
 │                                          setup + test logs             ├─> CloudWatch dashboard
 └─ app container stdout (JSON line per request)                          │   "TechTriage-Production"
      └─ Docker awslogs driver -> Logs group /techtriage/production/app   │
           └─ metric filters -> RequestCount, RequestLatency, Http5xxCount┤
Route 53 health check (outside AWS) -> GET http://3.232.71.71/health ─────┘
                                                                          │
                                    7 CloudWatch alarms ─> SNS topic ─> team email
```

Custom metrics (namespace `TechTriage/Production`): `mem_used_percent`,
`disk_used_percent`, `RequestCount`, `RequestLatency`, `Http5xxCount` (5, as
planned in the brief).

## Changes from the Project Brief (record these in the final report)

| Brief said | What we did | Why |
|---|---|---|
| Metric filters read the **Gunicorn access log** | The app writes one **JSON line per request** to stdout and Docker's `awslogs` driver ships it to CloudWatch Logs | Gunicorn only arrives in Level 3. JSON fields (`status`, `duration_ms`) make exact metric filters; Level 3 keeps the same format so nothing changes later |
| Alarms tested by "briefly stopping the container" for 5xx | Test-only routes `/_fault/500` and `/_fault/slow`, **off unless** `FAULT_INJECTION=1` in Production's `.env` | A stopped container returns no response at all, so it can never produce a 5xx log line. The placeholder answers in ~1 ms, so it can't cross 500 ms without help |
| Locust load test for CPU and response time | CPU: busy loops on the server. Latency: slow requests from CloudShell | The placeholder is too light for Locust to push CPU to 70%; the alarm logic being tested is the same |
| (not in brief) | Disk I/O graphed from free `AWS/EBS` volume metrics | The unit's Level 2 description lists disk I/O |
| (not in brief) | `/health` probes excluded from request count and latency | Route 53 and Docker probe `/health` every few seconds and would swamp real traffic |

---

## Step 0: Before you start

- [ ] Learner Lab: **Start Lab**, wait for the green dot, open **AWS**, region
      **N. Virginia (us-east-1)**. A session lasts about 4 hours, so start a
      fresh one right before step 2.
- [ ] EC2 -> `techtriage-production` is **Running**. Start it if it isn't.
- [ ] Open **CloudShell** (the `>_` icon in the top bar) and get the scripts:

```bash
git clone https://github.com/NSDVnsdv/SWE40006techtriage.git
cd SWE40006techtriage/monitoring
```

## Step 1: Code changes (PR)

- [ ] `feature/level2-monitoring` -> PR into `develop` -> approved -> merged
- [ ] Release PR `develop` -> `main` -> approved -> merged
- [ ] CI on `main` is green (this moves the `:latest` image the server pulls)
- Evidence: both PRs, the green run and its log

## Step 2: Deploy the new image and ship app logs to CloudWatch (11.3)

Session Manager on Production, then:

```bash
sudo -i
curl -fsSL https://raw.githubusercontent.com/NSDVnsdv/SWE40006techtriage/main/monitoring/prod-enable-logging.sh | bash
```

- [ ] `docker compose ps` shows the app `Up (healthy)`, logging driver `awslogs`
- [ ] CloudWatch -> **Log groups** -> `/techtriage/production/app` -> stream
      `production-app` shows JSON access lines
- Evidence: terminal output, log stream screenshot

## Step 3: CloudWatch Agent (11.3)

```bash
bash /opt/techtriage/monitoring/prod-install-agent.sh
```

- [ ] Agent status `running`, no errors in its log
- [ ] After ~3 min: CloudWatch -> **Metrics** -> **All metrics** ->
      `TechTriage/Production` shows `mem_used_percent` and `disk_used_percent`
- Evidence: terminal output, metrics browser screenshot

## Step 4: Metric filters (CloudShell)

```bash
bash cw-01-metric-filters.sh
```

- [ ] 3 filters listed; sample log lines printed
- Evidence: output, Log group -> **Metric filters** tab screenshot

## Step 5: SNS email alerts (CloudShell)

```bash
bash cw-02-sns.sh <email1> <email2> <email3> <email4>
```

- [ ] Every member clicks **Confirm subscription** in the AWS email
- [ ] Send the test message (command is printed by the script), everyone receives it
- Evidence: SNS topic -> Subscriptions all **Confirmed**, test email screenshot

## Step 6: Route 53 uptime check (CloudShell)

```bash
bash cw-03-health-check.sh
```

- [ ] Checker results say `Success: HTTP Status Code 200`
- If Route 53 is blocked on the Learner Lab account, record the error in the
  error log and tell the team (fallback is decided then).
- Evidence: output, Route 53 -> Health checks screenshot (status **Healthy**)

## Step 7: Seven alarms (CloudShell)

```bash
bash cw-04-alarms.sh
```

| Alarm | Metric | Fires when |
|---|---|---|
| `techtriage-prod-cpu-high` | EC2 CPUUtilization | average > 70% for 2 x 5 min |
| `techtriage-prod-memory-high` | mem_used_percent | > 80% for 5 min |
| `techtriage-prod-disk-high` | disk_used_percent (/) | > 80% |
| `techtriage-prod-latency-p95-high` | RequestLatency p95 | > 500 ms for 5 min |
| `techtriage-prod-http-5xx` | Http5xxCount | > 5 in 5 min |
| `techtriage-prod-status-check-failed` | EC2 StatusCheckFailed | failed 2 min in a row |
| `techtriage-prod-health-check-down` | Route 53 HealthCheckStatus | checkers report unhealthy |

- [ ] All 7 listed, all reach **OK** within a few minutes
- Evidence: CloudWatch -> **Alarms** list screenshot

## Step 8: Dashboard (CloudShell)

```bash
bash alarm-test-cloudshell.sh traffic &   # some normal traffic so graphs aren't empty
bash cw-05-dashboard.sh
```

- [ ] Dashboard `TechTriage-Production` shows every widget with data
- Evidence: full-page dashboard screenshot (set the time range to 1h)

## Step 9: Prove the alarms work (11.4)

Run several at once to save time. For each one record: test START time, alarm
ALARM time (`cw-status.sh`), email arrival time. Target: alarm -> email within 5 min.

| Alarm | Where | Command | Takes |
|---|---|---|---|
| cpu-high | Production | `bash /opt/techtriage/monitoring/alarm-test-prod.sh cpu` | ~10-15 min |
| memory-high | Production | `bash /opt/techtriage/monitoring/alarm-test-prod.sh memory` | ~6-7 min |
| disk-high | Production | `bash /opt/techtriage/monitoring/alarm-test-prod.sh disk` | ~2-3 min |
| latency-p95-high | CloudShell | `bash alarm-test-cloudshell.sh latency` | ~6-7 min |
| http-5xx | CloudShell | `bash alarm-test-cloudshell.sh errors` | ~2-6 min |
| health-check-down | Production | `bash /opt/techtriage/monitoring/alarm-test-prod.sh downtime` | ~3-4 min |
| status-check-failed | CloudShell | `bash alarm-test-cloudshell.sh statuscheck` (**simulation**) | instant |

Latency and 5xx need the fault routes on first, and off straight after:

```bash
bash /opt/techtriage/monitoring/prod-fault-injection.sh on    # Production
# ... run the latency and errors tests from CloudShell ...
bash /opt/techtriage/monitoring/prod-fault-injection.sh off   # Production
```

Don't run `downtime` at the same time as latency/errors (the app is stopped).
`alarm-test-prod.sh status` shows what's running; `cleanup` stops everything.

- [ ] Every alarm went OK -> ALARM -> OK, and the emails arrived
- [ ] Fault routes are **off** again (`/_fault/500` returns 404)
- Evidence: `bash cw-status.sh` output, dashboard during tests, alarm emails,
  alarm history tab

---

## Screenshot checklist

Save as `L2-<nn>-<name>.png` with the matching text output as `.txt`.

| # | Screenshot | Text to copy | Done |
|---|---|---|---|
| 01 | PRs merged + green CI run on `main` | CI log | [ ] |
| 02 | Session Manager: `prod-enable-logging.sh` | full output | [ ] |
| 03 | Log group `/techtriage/production/app` with JSON lines | n/a | [ ] |
| 04 | Session Manager: `prod-install-agent.sh` | full output | [ ] |
| 05 | Metrics browser: `TechTriage/Production` | n/a | [ ] |
| 06 | Metric filters tab (3 filters) | `cw-01` output | [ ] |
| 07 | SNS subscriptions confirmed + test email | `cw-02` output | [ ] |
| 08 | Route 53 health check Healthy | `cw-03` output | [ ] |
| 09 | Alarms list (7, all OK) | `cw-04` output | [ ] |
| 10 | Dashboard with live data | n/a | [ ] |
| 11-17 | Each alarm in ALARM + its email | `alarm-test-*` output | [ ] |
| 18 | Dashboard during tests (spikes visible) | n/a | [ ] |
| 19 | Alarm history | `cw-status.sh` output | [ ] |

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| App won't start after step 2, `awslogs` error | Instance role can't write logs. Check the role has CloudWatch Logs access; to get the site back fast, remove the `COMPOSE_FILE=` line from `.env` and `docker compose up -d` |
| No `TechTriage/Production` namespace | Agent not running (`amazon-cloudwatch-agent-ctl -m ec2 -a status`), or wait 3-5 min |
| Metric filters exist but metrics stay empty | Filters only count lines that arrive **after** they are created. Send traffic, wait 2-3 min |
| `cw-04` says no `disk_used_percent` | Agent not started yet (step 3) or less than ~5 min of data |
| Alarm stuck in `INSUFFICIENT_DATA` | Normal for latency/5xx until requests arrive; send traffic |
| No email | Subscription still `PendingConfirmation`, or check spam |

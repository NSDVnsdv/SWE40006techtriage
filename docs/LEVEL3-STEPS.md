# Level 3 runbook: Application deployment and verification

Every Level 3 step in order, what was done, the exact commands and the real results.
Brackets like (9.1) are Table 10 steps in the Project Brief.

**For every step: take a screenshot AND copy the terminal/log text.** Problems go in
[error-log.md](error-log.md) straight away.

Legend: `[x]` done, `[ ]` to do.

---

## How Level 3 fits together

```
feature/* branch -> pull request -> develop -> main
                         |
   CI (ci.yml)    "test" job: ruff lint, rule schema check, 64 unit + 14 integration tests
                  (throwaway PostgreSQL), coverage gates: 80% overall, 95% rules.py
                         |  only if "test" passes
                  "build" job: Docker image tagged with the full commit SHA -> GHCR
                         |
   Deploy (deploy.yml, "Run workflow": environment + image SHA)
      -> AWS Systems Manager Run Command on that server: download that commit's compose
         files, set IMAGE_TAG in .env, docker compose pull app, docker compose up -d
      -> wait until /health says "database": "connected"
      -> verify: 7 Playwright browser tests on Testing, 2 smoke tests everywhere else

Each EC2 server (Docker Compose project "techtriage"):
   app  (Gunicorn, server port 80 -> 8000, JSON access log)
     <-- private network "backend" -->
   db   (postgres:17-alpine, data in named volume pgdata, port 5432 never published)
```

## What is where

| Path | Purpose |
|---|---|
| `app.py` | Flask app: home, results, Yes/No feedback, stats, `/health`, `/version`, Level 2 `/_fault` pages |
| `rules.py`, `rules/*.json` | Rules engine and the 25 rules in 5 categories. `python rules.py` is the rule schema check |
| `templates/` | The 4 page templates (Bootstrap 5.3.8 from a CDN with an integrity check) |
| `gunicorn.conf.py` | Port 8000, 2 workers, one JSON access-log line per request, creates the tables on start-up |
| `Dockerfile`, `compose.yaml`, `.env.example` | The image, the app + PostgreSQL stack, and the settings template |
| `tests/` | `test_unit.py` (64), `test_integration.py` (14), `test_e2e.py` (7 Playwright), `test_smoke.py` (2) |
| `pyproject.toml` | pytest and coverage settings (80% gate) |
| `.github/workflows/ci.yml`, `deploy.yml` | The CI pipeline and the deploy workflow |
| `docs/evidence/` | Test-the-tests drill results (B8) |

## Running it on your own computer (Windows, VS Code terminal)

```
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt
docker run -d --name techtriage-db -e POSTGRES_USER=techtriage -e POSTGRES_PASSWORD=techtriage -e POSTGRES_DB=techtriage -p 5432:5432 postgres:17-alpine
.venv\Scripts\python app.py
```

Open http://127.0.0.1:5000. To run it exactly like a server instead: copy `.env.example`
to `.env`, set `IMAGE_TAG` to a full commit SHA from a green CI run and `HOST_PORT=8080`,
then `docker compose up -d` and open http://localhost:8080.

Tests:

```
.venv\Scripts\python rules.py
.venv\Scripts\python -m pytest tests/test_unit.py
$env:TEST_DATABASE_URL = "postgresql://techtriage:techtriage@localhost:5434/techtriage"
.venv\Scripts\python -m pytest tests/test_unit.py tests/test_integration.py --cov --cov-fail-under=80
.venv\Scripts\python -m playwright install chromium
.venv\Scripts\python -m pytest tests/test_e2e.py --base-url http://localhost:8080
$env:EXPECTED_SHA = "<full commit SHA>"
.venv\Scripts\python -m pytest tests/test_smoke.py --base-url http://<server address>
```

The integration tests **empty the tables** of whatever database `TEST_DATABASE_URL` points
at, so always use a throwaway one (above: a separate container on port 5434), never a
database with data you want to keep.

---

## Part A: Build the app (9.1, 9.3)

- [x] A1 Python 3.12 virtual environment; `requirements.txt` (Flask 3.1.3, Gunicorn 26.2.0, psycopg 3.3.6) and `requirements-dev.txt` (pytest, pytest-cov, pytest-playwright, ruff)
- [x] A2 25 rules in 5 JSON files (Docker, Git and GitHub, Python, Localhost and ports, Network and setup), 5 each. "Python virtual environment will not activate" is left out for the Level 4 demo
- [x] A3 `rules.py` loads and checks the rules; `python rules.py` prints `Rule check passed: 25 rules in 5 categories`
- [x] A4 `app.py`: every page and route, tested against a real PostgreSQL
- [x] A5 Tables `triage_sessions` and `feedback` (each feedback row linked to a session, one answer per session), created with `CREATE TABLE IF NOT EXISTS` when Gunicorn starts
- [x] A6 Templates with an environment badge (blue development, amber testing, purple staging, green production) and a version footer
- [x] A7 `.env.example`; real `.env` files stay on the servers and are blocked by `.gitignore`
- [x] A8 Real `Dockerfile` (Python 3.12 slim, non-root user, commit SHA baked in as `APP_VERSION`); placeholder deleted
- [x] A9 `compose.yaml`: app + PostgreSQL, private network, named volume, port 5432 never published, app waits for the database health check
- [x] A10 `docker compose up` on the PC with the CI-built image: 12/12 automated page checks passed

## Part B: Automated tests (10.1, 10.3, 11.1)

| Check | Brief target | Result |
|---|---|---|
| Unit tests | at least 30 | **64**, no database needed |
| Integration tests (real PostgreSQL) | at least 8 | **14** |
| Playwright browser tests | at least 5 | **7** |
| Smoke tests | 2 | **2** |
| Statement coverage | 80% overall, 95% rules engine | **98.6%** overall, **100%** `rules.py` |
| Rule file validity | 100% | `python rules.py` in every CI run |
| Pull request checks | 5 minutes or less | about **1 minute** (test 32 s + build 28 s) |
| Seeded faults caught | 5 of 5 | **5 of 5** ([evidence](evidence/B8-seeded-faults.txt)) |
| Flaky tests | 0 | **0** in 10 runs of 87 tests ([evidence](evidence/B8-flaky-check.txt)) |

- [x] B4 The `test` job in `ci.yml` runs on every push and pull request and saves `test-reports` (JUnit + coverage XML + HTML) with each run. `build` now waits for `test`
- [x] B7 `build` and `test` are both required checks: one ruleset covering `main` and `develop` (1 approval, no force push, no deletion, nobody can bypass)

## Part C: Deploy through the pipeline

- [x] C1 Repository secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (Learner Lab keys). **They expire with the lab session.** To refresh: Learner Lab -> Start Lab -> AWS Details -> AWS CLI: Show, then the repo owner pastes **only the part after `=`** into each secret (Settings -> Secrets and variables -> Actions -> pencil -> Update secret)
- [x] C2 GitHub environments, each with one variable called exactly `INSTANCE_ID`:

| Environment | INSTANCE_ID | Address |
|---|---|---|
| development | `i-04b3b7b74fa92f322` | changes on stop/start (looked up at deploy time) |
| testing | `i-0297da3eacd2c0f10` | changes on stop/start (looked up at deploy time) |
| staging | `i-0da2d24c792889a0a` | changes on stop/start (looked up at deploy time) |
| production | `i-05fa5eb69c835d120` | `3.232.71.71` (Elastic IP) |

- [x] C3 Each server got its own random `DB_PASSWORD` in `/opt/techtriage/.env`, made on the server itself, in one Systems Manager command from CloudShell (all 4: `Success`, `DB_PASSWORD lines = 1`):

```
cat > c3.json <<'EOF'
{"commands": [
  "cd /opt/techtriage",
  "grep -q '^DB_PASSWORD=.' .env || echo \"DB_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_hex(16))')\" >> .env",
  "chmod 600 .env",
  "echo \"$(grep ^APP_ENV= .env): DB_PASSWORD lines = $(grep -c '^DB_PASSWORD=.' .env)\""
]}
EOF
ID=$(aws ssm send-command --document-name AWS-RunShellScript --comment "TechTriage C3: add DB_PASSWORD" --targets "Key=tag:Name,Values=techtriage-development,techtriage-testing,techtriage-staging,techtriage-production" --parameters file://c3.json --query Command.CommandId --output text); sleep 15
aws ssm list-command-invocations --command-id "$ID" --details --query "CommandInvocations[].[InstanceId, Status, CommandPlugins[0].Output]" --output text
```

- [x] C4 To deploy: repo -> **Actions** -> **Deploy** -> **Run workflow** -> branch `main`, pick the environment, paste the **full 40-character commit SHA** of a green CI run on `main` -> **Run workflow**
- [x] C5 PR #4 (`feature/level3-app` -> `develop`) and PR #5 (`develop` -> `main`), both approved and green. Release image `ghcr.io/nsdvnsdv/swe40006techtriage:b2346bb05f2fbf5a70a1edd182589b7a95eca8f6`, digest `sha256:865661e640b98d68b9c8610fc2c29a24612e032808464ea0412a5ce0e9ab0333`
- [x] C6 The same image deployed to every server, never rebuilt:

| Deploy run | Server | Deploy time | Tests on the live server | Result |
|---|---|---|---|---|
| #3 | testing | 38 s | 7 Playwright passed | success |
| #4 | staging | 39 s | 2 smoke passed | success |
| #5 | production | 38 s | 2 smoke passed | success |
| #6 | development | 39 s | 2 smoke passed | success |

Runs #1 and #2 stopped safely before changing any server (error log entries 11 and 12).
All runs: https://github.com/NSDVnsdv/SWE40006techtriage/actions/workflows/deploy.yml

## Part D: Verify on Production

- [x] D1 Live site http://3.232.71.71: Docker -> "Port is already allocated when starting a container" -> 4 numbered steps -> **Yes** -> "Thanks, your answer has been saved". Stats went from **0 to 1 session** (most common Docker, fix rate 100%), so the live database saved it
- [x] D2 Testing, Staging and Production all answer `/health` with HTTP 200 and `"database": "connected"`, and `/version` shows the same commit `b2346bb05f2fbf5a70a1edd182589b7a95eca8f6`
- [x] D3 App container restarted on Production through Systems Manager: **1 session before, 1 session after**, `/health` still `"database": "connected"`. `docker compose ps` showed the app freshly restarted on `b2346bb` while `db` kept running (healthy, port 5432 not published), and the data lives in the named volume `techtriage_pgdata`
- [x] D4 Level 2 still works with the real app: CloudWatch counted **70 requests** in the 08:22 UTC 5-minute slot (the D1 run plus 60 page visits), so the new app's JSON log lines reach CloudWatch and the metric filters read them; **p95 latency 19.7 ms** (alarm at 500 ms); **memory used 38.3%** with PostgreSQL added (alarm at 80%); Route 53: **16 of 16 checkers "HTTP Status Code 200, OK"**; **all 7 alarms OK**

D3 and D4 were run from AWS CloudShell in one paste:

```
cat > d3.json <<'EOF'
{"commands": [
  "cd /opt/techtriage",
  "echo \"BEFORE restart: $(curl -s localhost/stats | grep -o 'total-sessions\">[0-9]*' | grep -o '[0-9]*$') sessions\"",
  "docker compose restart app",
  "sleep 20",
  "docker compose ps",
  "echo \"AFTER restart: $(curl -s localhost/stats | grep -o 'total-sessions\">[0-9]*' | grep -o '[0-9]*$') sessions\"",
  "echo \"health: $(curl -s localhost/health)\"",
  "echo \"database volume: $(docker volume ls -q | grep pgdata)\""
]}
EOF
ID=$(aws ssm send-command --instance-ids i-05fa5eb69c835d120 --document-name AWS-RunShellScript --comment "TechTriage D3: restart app, data survives" --parameters file://d3.json --query Command.CommandId --output text); sleep 40
aws ssm get-command-invocation --command-id "$ID" --instance-id i-05fa5eb69c835d120 --query '[Status, StandardOutputContent]' --output text
aws cloudwatch get-metric-statistics --namespace TechTriage/Production --metric-name RequestCount --start-time $(date -u -d '-30 min' +%FT%TZ) --end-time $(date -u +%FT%TZ) --period 300 --statistics Sum --query 'sort_by(Datapoints,&Timestamp)[].[Timestamp,Sum]' --output text
aws cloudwatch get-metric-statistics --namespace TechTriage/Production --metric-name RequestLatency --start-time $(date -u -d '-30 min' +%FT%TZ) --end-time $(date -u +%FT%TZ) --period 300 --extended-statistics p95 --query 'sort_by(Datapoints,&Timestamp)[].[Timestamp,ExtendedStatistics.p95]' --output text
aws cloudwatch get-metric-statistics --namespace TechTriage/Production --metric-name mem_used_percent --dimensions Name=InstanceId,Value=i-05fa5eb69c835d120 --start-time $(date -u -d '-15 min' +%FT%TZ) --end-time $(date -u +%FT%TZ) --period 300 --statistics Maximum --query 'sort_by(Datapoints,&Timestamp)[-1].Maximum' --output text
HC=$(aws route53 list-health-checks --query "HealthChecks[?HealthCheckConfig.IPAddress=='3.232.71.71'].Id | [0]" --output text)
aws route53 get-health-check-status --health-check-id "$HC" --query 'HealthCheckObservations[].StatusReport.Status' --output text | tr '\t' '\n' | sort | uniq -c
aws cloudwatch describe-alarms --alarm-name-prefix techtriage-prod --query 'MetricAlarms[].[AlarmName,StateValue]' --output table
```

---

## Screenshot checklist

Save as `L3-<nn>-<name>.png` with the matching text as `.txt`.

| # | Screenshot | Text to copy | Done |
|---|---|---|---|
| 01 | PC: `docker compose up -d` and `docker compose ps` | terminal output | [ ] |
| 02-07 | PC copy (http://localhost:8080): home, category picked, results with steps, Yes saved, No saved, stats | n/a | [ ] |
| 08-09 | PC copy: `/health` and `/version` | page text | [ ] |
| 10 | `python rules.py` | output | [ ] |
| 11 | First CI run with the `test` job (all steps green) and its `test-reports` artifact | pytest + coverage part of the log | [ ] |
| 12-13 | PR #4 and PR #5: green `test` + `build` checks, approval, merged | n/a | [ ] |
| 14 | Ruleset for `main` + `develop` (already taken: IMG_9465, IMG_9466) | n/a | [x] |
| 15 | Seeded-fault drill and flaky check | `docs/evidence/*.txt` | [ ] |
| 16-17 | Secrets page (names only) and Environments page with one `INSTANCE_ID` (repo owner) | n/a | [ ] |
| 18 | CloudShell: C3 database passwords on all 4 servers (already taken) | output | [x] |
| 19 | Deploy run #3 (testing): workflow graph, Systems Manager output, 7 Playwright passed | deploy + verify logs | [ ] |
| 20-22 | Deploy runs #4 (staging), #5 (production), #6 (development) | deploy + verify logs | [ ] |
| 23 | `/health` and `/version` from all 4 servers | page text | [ ] |
| 24 | Production: full troubleshooting run, then the stats page (D1) | n/a | [ ] |
| 25 | Production: app restart, `docker compose ps`, stats unchanged (D3) (CloudShell output already taken) | CloudShell output | [x] |
| 26 | CloudWatch: dashboard with the request/latency spike at 08:22 UTC, alarm list, Route 53 healthy (D4) (CloudShell output already taken; dashboard still to take) | CloudShell output | [ ] |
| 27 | Deploy runs #1 and #2 (the two safe failures, for the error log) | the error lines | [ ] |

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `docker compose up`: "required variable ... is missing a value" | No `.env` next to `compose.yaml`. Copy `.env.example` to `.env` and fill it in |
| Deploy stops at "Check the inputs" | The environment has no variable called exactly `INSTANCE_ID`, or the image tag is not the full 40-character SHA |
| Deploy fails at "Log in to AWS": "security token ... invalid" | The secrets were pasted with the `name=` part or a cut-off token. Re-paste only the values, all 3 from one AWS Details view |
| Deploy fails at "Log in to AWS": "security token ... expired" | The Learner Lab session ended. Start Lab, then re-paste all 3 secrets |
| Deploy fails at "Find the server's address": "no public address" | The server is stopped. Start it in EC2 (its address changes, the workflow finds the new one) |
| Systems Manager status not `Success` | Read the printed server output. "DB_PASSWORD is missing" means step C3 was not done on that server |
| `/health` returns 503 "unreachable" | The database container is down: `docker compose ps` and `docker compose logs db` on that server |

---

## Hand-over to Level 4

What Level 4 can build on, and what is already done.

**CI (`ci.yml`)**: runs on every push and pull request. `test` (lint, rule check, unit +
integration tests, coverage gates, `test-reports` artifact), then `build` (needs `test`):
image tagged with the full commit SHA, plus `latest` on `main`. Pull requests build but never
push. The run's Summary page shows the commit, tags and the **image digest**.

**Deploy (`deploy.yml`)**: inputs `environment` and `image_tag` (full 40-character SHA). It
already supports `workflow_call`, so CI can call it directly:

```yaml
  deploy-testing:
    needs: build
    uses: ./.github/workflows/deploy.yml
    with:
      environment: testing
      image_tag: ${{ github.sha }}
    secrets: inherit
```

It already has:

- **one deploy at a time per server** (`concurrency: deploy-<environment>`, queued, never cancelled), which covers "two releases can never deploy to Production at the same time"
- the deploy job runs **inside the GitHub environment**, so a required reviewer on `production` makes it wait for an **Approve** click with no workflow change
- the server prints `Previous image: IMAGE_TAG=<sha>` before switching, and `/version` always shows the running SHA, which gives the commit to roll back to
- a `verify` job (Playwright on testing, smoke tests elsewhere) that saves `<environment>-test-reports`, including Playwright traces when a test fails

**Level 4 tasks mapped to what exists**

| Level 4 task | Status / what is left |
|---|---|
| Merge to `develop` deploys Development | Add a job in `ci.yml` that calls `deploy.yml` with `environment: development` on pushes to `develop` |
| Merge to `main`: build once, Testing + Playwright, Staging + smoke, wait, Production | Chain calls to `deploy.yml` (`needs:`) on pushes to `main`, all with `image_tag: ${{ github.sha }}` |
| Approval gate | Repo owner: Settings -> Environments -> production -> Required reviewers |
| Concurrency | Done (per environment) |
| Automatic rollback | Read Production's `/version` before deploying; if the Production deploy fails, call `deploy.yml` again with that SHA |
| Artifacts: test reports, coverage, Playwright traces, image digest | Done (CI `test-reports`, deploy `<environment>-test-reports`, digest in the CI Summary) |

**Before every deploy session (and before the demo)**: Learner Lab -> Start Lab, then the repo
owner re-pastes the 3 AWS secrets (values only). Stopped servers must be started in EC2 first.

**Demo rule**: add this as the last entry of `rules/python.json` (put a comma after the
previous rule's closing `}`). It passes the rule check and every test (checked: 26 rules,
78 tests pass), and the Python category then shows 6 symptoms:

```json
  {
    "id": "python-06",
    "category": "Python",
    "symptom": "Python virtual environment will not activate",
    "steps": [
      "On Windows PowerShell run '.venv\\Scripts\\Activate.ps1', on Mac or Linux run 'source .venv/bin/activate'.",
      "If PowerShell says running scripts is disabled, run 'Set-ExecutionPolicy -Scope CurrentUser RemoteSigned' once, then try again.",
      "If the .venv folder is missing or broken, delete it and create it again with 'python -m venv .venv'.",
      "Check it worked: the terminal line now starts with (.venv)."
    ]
  }
```

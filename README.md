# TechTriage

**TechTriage** is a small website that helps students fix common technical problems.
You pick a category (for example Docker or Python), pick the problem that matches what
you see, and the site gives you numbered steps to fix it. You then answer "Did this fix
it?", and the site keeps simple stats.

The website is deliberately small. The real point of this project is the **DevOps
pipeline** around it: the automatic system that tests every change, packages it, and
delivers it through four separate servers (Development, Testing, Staging, Production).

SWE40006 Software Deployment and Evolution, Group 05 (CL03 Wed 16:30).

> **Current state: Level 3 complete.** All four servers run the real TechTriage app with its
> own database, delivered by the pipeline. Live site: **http://3.232.71.71** (Production).
> Level 4 (full automation from one push) is in progress.

---

## How it works

How one change travels from a developer's computer to the live website:

```mermaid
flowchart TB
    A["Step 1: Your computer<br/>write code, run the app and tests"] -->|"git push to a feature branch"| B["Step 2: GitHub<br/>stores the code and its history"]
    B -->|"open a pull request"| C["Step 3: GitHub Actions: test job<br/>lint, rule check, 78 automatic tests"]
    C -->|"all green, a teammate approves, merge to main"| D["Step 4: GitHub Actions: build job<br/>packs the app into a Docker image<br/>labelled with the commit ID"]
    D --> E[("Step 5: GHCR<br/>stores the finished image")]
    E --> F["Step 6: Deploy workflow<br/>press Run workflow, pick a server and an image"]
    F -->|"AWS Systems Manager sends the update command"| G1
    G1["Step 7: Development server (AWS EC2)"] --> G2["Testing server (AWS EC2)<br/>+ 7 Playwright browser tests"] --> G3["Staging server (AWS EC2)<br/>+ 2 smoke tests"] --> G4["Production server (AWS EC2)<br/>+ 2 smoke tests"]
    U(("Visitors")) -->|"the live site, 3.232.71.71"| G4
    G4 --> H["Step 8: CloudWatch watches Production<br/>graphs and 7 alarms"]
    H -->|"if something goes wrong"| I["Step 9: SNS emails the team"]
```

What runs inside **each** of the four servers:

```mermaid
flowchart LR
    V["Visitor's browser"] -->|"port 80"| G["app container<br/>Gunicorn running the Flask app"]
    G -->|"private network, never public"| P[("db container<br/>PostgreSQL, data kept in a volume")]
    G -.->|"one log line per request (Production only)"| L["CloudWatch Logs"]
```

### How a change reaches Production

1. **Write it.** A team member makes a change on their own computer, on a new
   `feature/...` branch, and runs the app and the tests locally.
2. **Share it.** They push the branch to GitHub and open a **pull request** (a request to
   add their change to the shared code).
3. **Check it automatically.** GitHub Actions runs the `test` job: it checks the code for
   mistakes, checks every rule file, and runs 78 tests against a temporary database.
4. **Review it.** A teammate reviews and approves. The change can only be merged when the
   tests pass **and** someone has approved (nobody can skip this, not even the owner).
5. **Package it.** After merging, the `build` job packs the whole app into a **Docker
   image** and labels it with the commit ID (a unique code for that exact version).
6. **Store it.** The image is uploaded to **GHCR**, ready for the servers to download.
7. **Deliver it.** The **Deploy** workflow tells one server, through **AWS Systems
   Manager**, to download that exact image and restart the app with it. The same image goes
   to Testing, then Staging, then Production. It is never rebuilt in between.
8. **Prove it works.** After each deploy the workflow checks `/health`, then runs the
   **Playwright** browser tests on Testing, or the quick **smoke tests** elsewhere.
9. **Watch it.** On Production, **CloudWatch** collects graphs (CPU, memory, disk, requests,
   response time, errors) and **SNS** emails the team if any of the 7 alarms goes off.

---

## Tools used

| Tool | What it is | What we use it for |
|---|---|---|
| **Python** | A popular, readable programming language | The whole app and its tests are written in Python 3.12 |
| **Flask** | A small Python toolkit for building websites | Decides what each page shows and saves the Yes/No answers (`app.py`) |
| **Jinja + Bootstrap** | Jinja fills page templates with data; Bootstrap is ready-made styling | The four page designs in `templates/` |
| **Gunicorn** | A program that runs a Python website for real visitors | Serves the Flask app on the servers with 2 workers, so it handles more than one visitor at a time. Flask's own built-in server is only for testing on your computer |
| **PostgreSQL** | A database: it stores data safely in tables | Saves each troubleshooting session and its Yes/No answer for the stats page |
| **JSON rule files** | Plain text files holding the troubleshooting content | The 25 problems and their fix steps live in `rules/`, so changing content is a normal reviewed code change |
| **Git and GitHub** | Git tracks every change to the code; GitHub stores it online for the team | Shared code, pull requests, reviews and the branch rules |
| **GitHub Actions** | GitHub's built-in robot that runs jobs automatically | Runs the tests on every push and pull request, builds the image, and runs deploys |
| **Docker** | Packs an app and everything it needs into one **image**, which runs the same way on any computer | The app is shipped as one Docker image, so all four servers run identical code |
| **Docker Compose** | Starts several Docker containers together from one file | Runs the app and PostgreSQL side by side on each server (`compose.yaml`) |
| **GHCR** | GitHub Container Registry: online storage for Docker images | Holds every built image, labelled with its commit ID |
| **AWS** | Amazon Web Services: rentable computers and tools in the cloud | Hosts the four servers and the monitoring (through the AWS Academy Learner Lab account) |
| **EC2** | AWS virtual computers | Our four servers: Development, Testing, Staging, Production |
| **AWS Systems Manager** | Lets you send commands to, and log in to, servers without opening SSH | The deploy workflow uses it to update servers; we use Session Manager to log in |
| **CloudWatch** | AWS's monitoring service: graphs, logs and alarms | Watches Production's CPU, memory, disk, requests, response time and errors |
| **SNS** | AWS's notification service | Emails the team when a CloudWatch alarm goes off |
| **Route 53 health check** | AWS checkers around the world that keep calling a web address | Calls Production's `/health` every 30 seconds, from outside AWS |
| **pytest** | A Python tool that runs automated tests | Runs the 64 unit tests and 14 integration tests, and measures coverage |
| **Playwright** | Drives a real web browser automatically, like a robot user | Clicks through the live Testing site after every Testing deploy |
| **ruff** | A code checker (linter) | Catches mistakes such as unused code before tests even run |

**Common terms:**
- **Commit ID (SHA):** a unique 40-character code for one exact version of the code.
- **Pull request:** a request to add a change to the shared code, with automatic checks and a review.
- **Container:** a running copy of a Docker image.
- **Volume:** storage that survives when a container is replaced, so the database keeps its data.
- **Environment:** one of the four servers, each with its own settings and its own database.

---

## The four servers

| Environment | Instance ID | Address | What it is for |
|---|---|---|---|
| development | `i-04b3b7b74fa92f322` | changes when stopped and started | Trying out merged team changes |
| testing | `i-0297da3eacd2c0f10` | changes when stopped and started | Automatic browser tests (Playwright) |
| staging | `i-0da2d24c792889a0a` | changes when stopped and started | A final check on a Production-like copy |
| production | `i-05fa5eb69c835d120` | **http://3.232.71.71** (fixed Elastic IP) | The live site, monitored by CloudWatch |

All four are Amazon Linux 2023, `t3.micro` (2 vCPUs, 1 GB memory), in AWS region
`us-east-1`. Each one has its **own separate database**, so test data never mixes with
Production. Only port 80 (web) is open: no SSH, and the database port is never public.
Development, Testing and Staging are stopped when not in use to save money, so check the
EC2 console for their current address. The deploy workflow looks it up by itself.

## The pages

| Address | What it shows |
|---|---|
| `/` | Home: pick a category, then the problem that matches yours |
| `/result/<number>` | The numbered fix steps, then "Did this fix it?" Yes / No |
| `/stats` | Total sessions, most common category and fix rate, from this server's database |
| `/health` | `{"database": "connected"}` with status 200 if the database answers, or status 503 if not. Used by the pipeline and the monitoring |
| `/version` | Which environment this is and which commit it is running. Used to prove the same version reached every server |

The coloured badge at the top of every page shows which server you are on: blue
development, amber testing, purple staging, green production.

---

## Running it on your own computer

You need Python 3.12 and Docker Desktop. In the VS Code terminal, from the project folder:

```
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt
docker run -d --name techtriage-db -e POSTGRES_USER=techtriage -e POSTGRES_PASSWORD=techtriage -e POSTGRES_DB=techtriage -p 5432:5432 postgres:17-alpine
.venv\Scripts\python app.py
```

Then open http://127.0.0.1:5000. The first line makes a **virtual environment** (a private
folder of Python packages for this project); the third starts a practice database in Docker.
Next time, just run `docker start techtriage-db` and `.venv\Scripts\python app.py`.

**To run it exactly like a server does** (app + database in Docker): copy `.env.example` to
`.env`, set `IMAGE_TAG` to a full commit ID from a green CI run and `HOST_PORT=8080`, then
run `docker compose up -d` and open http://localhost:8080.

## Running the tests

```
.venv\Scripts\python rules.py
.venv\Scripts\python -m pytest tests/test_unit.py
```

The integration tests need a **throwaway** database, because they empty its tables:

```
docker run -d --name tt-test-db -e POSTGRES_USER=techtriage -e POSTGRES_PASSWORD=techtriage -e POSTGRES_DB=techtriage -p 5434:5432 postgres:17-alpine
$env:TEST_DATABASE_URL = "postgresql://techtriage:techtriage@localhost:5434/techtriage"
.venv\Scripts\python -m pytest tests/test_unit.py tests/test_integration.py --cov --cov-fail-under=80
```

| Tests | How many | What they prove |
|---|---|---|
| Unit (`tests/test_unit.py`) | 64 | The rules, the stats maths and the input checks work, with no database needed |
| Integration (`tests/test_integration.py`) | 14 | Answers really are saved in and read back from PostgreSQL; `/health` gives 200 or 503 |
| Browser (`tests/test_e2e.py`) | 7 | A real browser can do a full troubleshooting run on the deployed Testing site |
| Smoke (`tests/test_smoke.py`) | 2 | After a deploy: the database is connected and the expected version is running |

Coverage (how much of the code the tests run) must be at least **80%** overall and **95%**
for the rules code, or the pipeline fails. It is currently 98.6% and 100%. The tests were
also tested: 5 deliberately planted bugs were all caught, and 10 repeat runs showed no
unreliable tests ([evidence](docs/evidence/)).

---

## Branch rules: how to make a change

1. Make a new branch from `develop` called `feature/<short-name>`.
2. Commit your change and push the branch to GitHub.
3. Open a pull request into `develop`. It needs **1 approval from a teammate** and both
   automatic checks (`test` and `build`) passing. You cannot approve your own.
4. When a release is ready, open a pull request from `develop` into `main`.
5. Nobody can push straight to `main` or `develop`, force-pushing is blocked, and the
   branches cannot be deleted.
6. Never commit passwords, AWS keys or `.env` files. The repo is public, and GitHub's
   secret scanning blocks pushes that contain keys.

## The pipeline files

| File | When it runs | What it does |
|---|---|---|
| [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | Every push and pull request | `test` job (lint, rule check, unit + integration tests, coverage gates, saves the reports), then `build` job (Docker image tagged with the commit ID, uploaded to GHCR; `latest` also moves on `main`; pull requests only build, never upload) |
| [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) | When someone presses **Run workflow** (and from Level 4's automation) | Updates one server to one image through AWS Systems Manager, waits for `/health`, then runs the Playwright or smoke tests against it |

## Deploying a version to a server

1. Find a green CI run on `main` and copy its **full commit ID** (40 characters).
2. In the repo, open **Actions**, then **Deploy**, then **Run workflow**.
3. Leave the branch as `main`, choose the environment, paste the commit ID, and click
   **Run workflow**.
4. Deploy in order: **testing**, then **staging**, then **production**. Each takes about
   40 seconds plus its tests.

The deploy uses AWS keys saved as GitHub secrets (`AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`). Learner Lab keys **expire when the lab
session ends**, so before deploying: Learner Lab, **Start Lab**, **AWS Details**, **Show**,
then the repo owner pastes only the part after each `=` into the three secrets. Each GitHub
environment holds one variable, `INSTANCE_ID`, which tells the workflow which server to update.

## Logging in to a server (Session Manager, no SSH)

1. AWS console, **EC2**, **Instances**, select the server, **Connect**, **Session Manager**
   tab, **Connect**.
2. Then:

```bash
sudo -i
cd /opt/techtriage
docker compose ps            # app and db should both be "Up (healthy)"
curl -s localhost/version    # which version is running
docker compose logs --tail 20 app
```

Each server keeps its private settings in `/opt/techtriage/.env` (environment name, image
version and its own database password). This file is never in GitHub.

## Monitoring (Production)

Dashboard: CloudWatch, **Dashboards**, **TechTriage-Production**. It shows CPU, memory,
disk, disk I/O, network, requests per minute, response time, errors, status checks and
uptime. The 7 alarms (`techtriage-prod-*`) email the team through the SNS topic
`techtriage-production-alerts`. How it was set up and tested: [docs/LEVEL2-STEPS.md](docs/LEVEL2-STEPS.md).

---

## What is in this repository

| Path | What it is |
|---|---|
| `app.py` | The Flask app: every page, `/health`, `/version`, and the database code |
| `rules.py`, `rules/` | The rules engine and the 25 troubleshooting rules (5 categories). `python rules.py` checks them |
| `templates/` | The page designs |
| `gunicorn.conf.py` | Gunicorn settings: port, 2 workers, one log line per request, creates the tables on start-up |
| `Dockerfile` | How the Docker image is built |
| `compose.yaml` | Runs the app + PostgreSQL on every server |
| `compose.monitoring.yaml` | Production only: sends the app's logs to CloudWatch |
| `.env.example` | A template of the settings each server keeps in its private `.env` |
| `requirements.txt`, `requirements-dev.txt` | The Python packages for the app, and the extra ones for testing |
| `pyproject.toml` | Test and coverage settings |
| `tests/` | The unit, integration, browser and smoke tests |
| `.github/workflows/` | The CI and Deploy pipelines |
| `server-setup.sh` | Sets up a brand-new EC2 server on its first start (Level 1) |
| `monitoring/` | CloudWatch set-up and alarm-test scripts (Level 2) |
| `docs/` | Step-by-step runbooks for each level, the error log and test evidence |

## Step-by-step guides

- [Level 1: pipeline infrastructure](docs/LEVEL1-STEPS.md)
- [Level 2: Production monitoring](docs/LEVEL2-STEPS.md)
- [Level 3: the app, tests and deployment](docs/LEVEL3-STEPS.md) (includes the hand-over to Level 4)
- [Error log: what broke and how it was fixed](docs/error-log.md)

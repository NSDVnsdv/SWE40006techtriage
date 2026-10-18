# TechTriage

Student technical troubleshooting assistant, deployed through a four-environment
DevOps pipeline. SWE40006 Software Deployment and Evolution, Group 05 (CL03 Wed 16:30).

> **Current state: Level 1 (pipeline infrastructure).** Every server runs a
> placeholder page that shows its environment name and the commit it was built
> from. The real TechTriage app arrives in Level 3.

## How the pipeline fits together

```
feature/* branch -> pull request -> develop -> main
                         |
                  GitHub Actions (CI)  builds the Docker image, tags it with the commit SHA
                         |
                  GHCR  ghcr.io/nsdvnsdv/swe40006techtriage:<sha>   (public, :latest = newest main build)
                         |
     EC2  development | testing | staging | production   (Docker Compose, pulled via Systems Manager)
```

## Agreed names

| Thing | Value |
|---|---|
| Repository | [`NSDVnsdv/SWE40006techtriage`](https://github.com/NSDVnsdv/SWE40006techtriage) (public) |
| Environments | `development`, `testing`, `staging`, `production` |
| AWS region | `us-east-1` (everything lives here) |
| EC2 Name tag | `techtriage-<env>` |
| EC2 Environment tag | `<env>` |
| Security group | `techtriage-web` (inbound HTTP 80 only) |
| Image | `ghcr.io/nsdvnsdv/swe40006techtriage:<commit-sha>` (GHCR names are lowercase) |

## Servers

| Environment | Instance ID | Address | Page |
|---|---|---|---|
| development | `i-...` | `...` (changes on stop/start) | http://.../ |
| testing | `i-...` | `...` (changes on stop/start) | http://.../ |
| staging | `i-...` | `...` (changes on stop/start) | http://.../ |
| production | `i-...` | `...` (Elastic IP, fixed) | http://.../ |

All four are Amazon Linux 2023, `t3.micro`, no key pair, no SSH. Development,
Testing and Staging are stopped when not in use, so check the EC2 console for
their current address.

Every server exposes:

- `/`: placeholder page (environment + commit SHA)
- `/health`: `{"status": "ok"}` (Level 3 adds the database check)
- `/version`: `{"environment": "...", "version": "<commit sha>"}`

## Logging in to a server (Session Manager, no SSH)

1. AWS console -> EC2 -> Instances -> select the server -> **Connect** ->
   **Session Manager** tab -> **Connect**.
2. Sessions start as `ssm-user`, which is not in the `docker` group, so switch to root first:

```bash
sudo -i
cd /opt/techtriage
docker compose ps          # app should be "Up (healthy)"
cat .env                   # APP_ENV, GHCR_OWNER, IMAGE_TAG for this server
curl -s localhost/version
docker compose logs --tail 20
```

To update a server to the newest `:latest` image by hand (Level 4 automates this):

```bash
cd /opt/techtriage && docker compose pull && docker compose up -d
```

Bootstrap log from first boot: `/var/log/techtriage-setup.log`.

## Branch rules

- New work goes on a `feature/<short-name>` branch made from `develop`.
- Open a pull request into `develop`. It needs **1 approval** from a teammate
  and a **passing `build` check**. You cannot approve your own PR.
- When a release is ready, open a pull request from `develop` into `main`.
- Nobody pushes straight to `main` or `develop`, and force-pushing is blocked.
- Never commit passwords, AWS keys or `.env` files. The repo is public, and
  secret scanning with push protection is switched on.

## CI (GitHub Actions)

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push and pull request:

| Event | What happens |
|---|---|
| Push to any branch | Build image, push `ghcr.io/nsdvnsdv/swe40006techtriage:<full sha>` |
| Push to `main` | Same, plus move the `:latest` tag |
| Pull request into `develop`/`main` | Build only, nothing is pushed |

## Running the placeholder locally

```bash
docker build --build-arg GIT_SHA=$(git rev-parse HEAD) -t ghcr.io/local/swe40006techtriage:dev .
GHCR_OWNER=local IMAGE_TAG=dev APP_ENV=development HOST_PORT=8080 docker compose up -d
# open http://localhost:8080
GHCR_OWNER=local APP_ENV=development docker compose down
```

## Repository layout

| Path | Purpose |
|---|---|
| `Dockerfile` | Placeholder image (Python stdlib server). **Replaced in Level 3** by Flask + Gunicorn. |
| `placeholder/server.py` | Placeholder page, `/health`, `/version`. **Deleted in Level 3.** |
| `compose.yaml` | Service definition used on every server. **Level 3 adds** the PostgreSQL `db` service and named volume. |
| `server-setup.sh` | EC2 user data: installs Docker + Compose, writes `/opt/techtriage/.env`, starts the app. |
| `.github/workflows/ci.yml` | Build and publish to GHCR. Level 3 adds tests; Level 4 adds deploy jobs. |
| `scripts/create-issues.sh` | Creates the level labels and Level 1 issues (GitHub CLI). |
| `docs/LEVEL1-STEPS.md` | Level 1 runbook: every step, what to screenshot. |
| `docs/error-log.md` | What broke, what we tried, what fixed it (for the final report). |

## What Level 3 changes

1. Replace `Dockerfile` with the Flask + Gunicorn image (keep the container
   listening on port **8000** and keep the `GIT_SHA` build arg -> `APP_VERSION`).
2. Delete `placeholder/`.
3. Add the `db` service (official `postgres` image) and a named volume to
   `compose.yaml`, on the private network only. Do **not** publish port 5432.
4. Keep `/health` and `/version`, with `/health` returning 200 only when the
   database answers.

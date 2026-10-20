# shellcheck shell=bash disable=SC2154
# Below is the code that runs ON THE SERVER (sent by the Deploy workflow through Systems Manager).
# The workflow adds two lines above it: REPO=<owner/repo> and TAG=<commit ID of the image to deploy>.

# Below is the code to stop at the first error and work in the folder holding the server's compose files and .env.
set -euo pipefail
cd /opt/techtriage

# Below is the code to refuse to deploy if this server has no database password in its .env yet.
grep -q '^DB_PASSWORD=.' .env || { echo "DB_PASSWORD is missing from /opt/techtriage/.env"; exit 1; }

# Below is the code to keep a copy of the current, working settings (.env and compose files) as "*.previous",
# so the automatic rollback can put them back if the new version fails its /health check.
cp -p .env .env.previous
cp -p compose.yaml compose.yaml.previous
if [ -f compose.monitoring.yaml ]; then cp -p compose.monitoring.yaml compose.monitoring.yaml.previous; fi
echo "Previous image: $(grep '^IMAGE_TAG=' .env || echo none)"

# Below is the code to download the compose files from the exact commit being deployed (Production also gets its monitoring add-on).
raw="https://raw.githubusercontent.com/$REPO/$TAG"
curl -fsSL "$raw/compose.yaml" -o compose.yaml
if grep -q '^COMPOSE_FILE=.*compose.monitoring.yaml' .env; then curl -fsSL "$raw/compose.monitoring.yaml" -o compose.monitoring.yaml; fi

# Below is the code to switch .env to the new image.
if grep -q '^IMAGE_TAG=' .env; then sed -i "s|^IMAGE_TAG=.*|IMAGE_TAG=$TAG|" .env; else echo "IMAGE_TAG=$TAG" >> .env; fi
echo "New image:      IMAGE_TAG=$TAG"

# Below is the code to point the server at the image store of whoever owns the repo now, in lowercase as GHCR needs,
# because image addresses include the owner's name (the repo moved from NSDVnsdv to TylerMarwood).
owner=$(echo "${REPO%%/*}" | tr '[:upper:]' '[:lower:]')
if grep -q '^GHCR_OWNER=' .env; then sed -i "s|^GHCR_OWNER=.*|GHCR_OWNER=$owner|" .env; else echo "GHCR_OWNER=$owner" >> .env; fi

# Below is the code to download only the new app image (the PostgreSQL image is kept), restart with it and show the result.
docker compose pull app
docker compose up -d
sleep 10
docker compose ps

# Below is the code to print the running image's digest (its unique fingerprint), so the pipeline can prove
# Testing, Staging and Production all run exactly the same image.
image=$(docker inspect --format '{{.Config.Image}}' techtriage-app-1)
echo "RUNNING_DIGEST=$(docker image inspect --format '{{index .RepoDigests 0}}' "$image" | sed 's/.*@//')"

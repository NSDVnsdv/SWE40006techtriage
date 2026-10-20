# shellcheck shell=bash
# Below is the code that runs ON THE SERVER when a Production deploy fails its /health check.
# It puts back the settings saved by server-deploy.sh, so the previous working image runs again.

# Below is the code to stop at the first error and work in the server's app folder.
set -euo pipefail
cd /opt/techtriage

# Below is the code to stop if there is no saved copy to go back to.
[ -f .env.previous ] || { echo "No .env.previous on this server, so there is nothing to roll back to"; exit 1; }

# Below is the code to put the previous .env and compose files back.
echo "Broken image:   $(grep '^IMAGE_TAG=' .env || echo none)"
cp -p .env.previous .env
cp -p compose.yaml.previous compose.yaml
if [ -f compose.monitoring.yaml.previous ]; then cp -p compose.monitoring.yaml.previous compose.monitoring.yaml; fi
echo "Rolled back to: $(grep '^IMAGE_TAG=' .env || echo none)"

# Below is the code to restart the app on the previous image (it is still on the server, so nothing new is downloaded).
docker compose up -d
sleep 10
docker compose ps

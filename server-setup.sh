#!/bin/bash
# Below is the code to set up a brand-new TechTriage EC2 server (Amazon Linux 2023) on its first boot.
# Paste the whole file into EC2 -> Launch instance -> Advanced details -> User data.

# Below is the code to name this server's environment. EDIT THIS VALUE FOR EACH SERVER:
# development, testing, staging or production.
ENV_NAME="development"

# Below is the code to say which GitHub repository the compose file is downloaded from.
GITHUB_OWNER="NSDVnsdv"
GITHUB_REPO="SWE40006techtriage"

# Below is the code to stop at the first error and copy everything this script prints into
# /var/log/techtriage-setup.log (it runs once, as root, on the first boot).
set -euxo pipefail
exec > >(tee -a /var/log/techtriage-setup.log) 2>&1

# Below is the code to set the Docker Compose version, the app folder, and the image owner in lowercase
# (GHCR image names must be lowercase).
COMPOSE_VERSION="v2.40.3"
APP_DIR="/opt/techtriage"
GHCR_OWNER=$(echo "$GITHUB_OWNER" | tr '[:upper:]' '[:lower:]')

# Below is the code to install the Docker engine and start it now and on every boot.
dnf install -y docker
systemctl enable --now docker

# Below is the code to install the Docker Compose plugin, which is not in the Amazon Linux 2023 repositories.
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Below is the code to download compose.yaml from the public repo and write this server's private settings (.env),
# readable by root only.
mkdir -p "$APP_DIR"
curl -fsSL "https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/main/compose.yaml" \
  -o "$APP_DIR/compose.yaml"
cat > "$APP_DIR/.env" <<EOF
APP_ENV=${ENV_NAME}
GHCR_OWNER=${GHCR_OWNER}
IMAGE_TAG=latest
EOF
chmod 600 "$APP_DIR/.env"

# Below is the code to download the public image from GHCR, start it and show that it is running.
cd "$APP_DIR"
docker compose pull
docker compose up -d
docker compose ps

# Below is the code to write a final line in the setup log.
echo "TechTriage setup finished for ${ENV_NAME}"

#!/bin/bash
# TechTriage EC2 bootstrap (Amazon Linux 2023). Paste the whole file into
# EC2 -> Launch instance -> Advanced details -> User data.
#
# EDIT THIS LINE FOR EACH SERVER:
ENV_NAME="development"     # development | testing | staging | production

GITHUB_OWNER="NSDVnsdv"
GITHUB_REPO="SWE40006techtriage"

# Runs once, as root, on first boot. Output: /var/log/techtriage-setup.log
set -euxo pipefail
exec > >(tee -a /var/log/techtriage-setup.log) 2>&1

COMPOSE_VERSION="v2.40.3"
APP_DIR="/opt/techtriage"
# GHCR image names must be lowercase.
GHCR_OWNER=$(echo "$GITHUB_OWNER" | tr '[:upper:]' '[:lower:]')

# 1. Docker engine
dnf install -y docker
systemctl enable --now docker

# 2. Docker Compose plugin (not in the Amazon Linux 2023 repos)
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# 3. Compose file from the public repo, plus this server's settings
mkdir -p "$APP_DIR"
curl -fsSL "https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/main/compose.yaml" \
  -o "$APP_DIR/compose.yaml"
cat > "$APP_DIR/.env" <<EOF
APP_ENV=${ENV_NAME}
GHCR_OWNER=${GHCR_OWNER}
IMAGE_TAG=latest
EOF
chmod 600 "$APP_DIR/.env"

# 4. Pull the public image from GHCR and start it
cd "$APP_DIR"
docker compose pull
docker compose up -d
docker compose ps

echo "TechTriage setup finished for ${ENV_NAME}"

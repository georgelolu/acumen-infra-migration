#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

RUNNER_USER="github-runner"
RUNNER_DIR="/opt/actions-runner"
REPOSITORY="__GITHUB_REPOSITORY__"
RUNNER_TOKEN="__GITHUB_RUNNER_TOKEN__"
RUNNER_NAME="__GITHUB_RUNNER_NAME__"

echo "=== Installing GitHub Actions Runner dependencies ==="

apt-get update -y

apt-get install -y \
  curl \
  jq \
  git \
  unzip \
  ca-certificates \
  docker.io

systemctl enable docker
systemctl start docker

echo "=== Creating runner user ==="

if ! id "${RUNNER_USER}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${RUNNER_USER}"
fi

usermod -aG docker "${RUNNER_USER}"

echo "=== Creating runner directory ==="

mkdir -p "${RUNNER_DIR}"
chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_DIR}"

echo "=== Downloading GitHub Actions Runner ==="

RUNNER_VERSION="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/^v//')"

if [ -z "${RUNNER_VERSION}" ] || [ "${RUNNER_VERSION}" = "null" ]; then
  echo "ERROR: Could not determine GitHub Actions Runner version."
  exit 1
fi

echo "Runner version: ${RUNNER_VERSION}"

cd "${RUNNER_DIR}"

if [ ! -f "${RUNNER_DIR}/run.sh" ]; then
  curl -fsSL \
    -o actions-runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

  tar xzf actions-runner.tar.gz
  rm -f actions-runner.tar.gz

  chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_DIR}"

  echo "=== Installing runner dependencies ==="

  "${RUNNER_DIR}/bin/installdependencies.sh"
fi

echo "=== Registering GitHub Actions Runner ==="

if [ ! -f "${RUNNER_DIR}/.runner" ]; then
  if [ -z "${REPOSITORY}" ]; then
    echo "ERROR: GitHub repository is empty."
    exit 1
  fi

  if [ -z "${RUNNER_TOKEN}" ]; then
    echo "ERROR: GitHub runner token is empty."
    exit 1
  fi

  echo "Repository: ${REPOSITORY}"
  echo "Runner name: ${RUNNER_NAME}"

  sudo -u "${RUNNER_USER}" \
    "${RUNNER_DIR}/config.sh" \
    --unattended \
    --url "https://github.com/${REPOSITORY}" \
    --token "${RUNNER_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "self-hosted,linux,x64,acumen,nomad" \
    --work "_work" \
    --replace
fi

echo "=== Creating systemd service ==="

cat > /etc/systemd/system/github-actions-runner.service <<SERVICE
[Unit]
Description=GitHub Actions Runner
After=network-online.target docker.service
Wants=network-online.target

[Service]
User=${RUNNER_USER}
WorkingDirectory=${RUNNER_DIR}
ExecStart=${RUNNER_DIR}/run.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable github-actions-runner
systemctl restart github-actions-runner

echo "=== GitHub Actions Runner installation complete ==="

systemctl --no-pager --full status github-actions-runner || true

mkdir -p /opt/acumen
touch /opt/acumen/github-runner-ready

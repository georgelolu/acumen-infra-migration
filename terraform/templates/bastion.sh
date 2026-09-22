#!/bin/bash

set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get upgrade -y

apt-get install -y \
  curl \
  unzip \
  jq \
  dnsutils \
  netcat-openbsd

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

echo "Acumen Bastion bootstrap completed." > /var/log/acumen-bastion-bootstrap.log

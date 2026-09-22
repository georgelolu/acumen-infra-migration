#!/bin/bash

set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

NODE_NAME="${node_name}"
PRIVATE_IP="${private_ip}"
CONSUL_VERSION="${consul_version}"
NOMAD_VERSION="${nomad_version}"
CONSUL_GOSSIP_KEY="${consul_gossip_key}"

mkdir -p /opt/acumen/bootstrap

exec > >(tee -a /var/log/acumen-cluster-bootstrap.log | logger -t acumen-bootstrap -s 2>/dev/console) 2>&1

echo "============================================"
echo "Acumen cluster bootstrap starting"
echo "Node: $${NODE_NAME}"
echo "Private IP: $${PRIVATE_IP}"
echo "============================================"

echo "Updating operating system..."

apt-get update -y

apt-get install -y \
  ca-certificates \
  curl \
  unzip \
  jq \
  dnsutils \
  netcat-openbsd \
  docker.io \
  dmidecode \
  dnsmasq \
  wget \
  gpg \
  lsb-release

systemctl enable docker
systemctl start docker

echo "Docker installed:"
docker --version

echo "Installing HashiCorp repository tools..."

wget -O- https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor \
  | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$${UBUNTU_CODENAME}") main" \
  | tee /etc/apt/sources.list.d/hashicorp.list

apt-get update -y

echo "Downloading Consul $${CONSUL_VERSION}..."

cd /tmp

curl -fsSLo "consul_$${CONSUL_VERSION}_linux_amd64.zip" \
  "https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip"

curl -fsSLo "consul_$${CONSUL_VERSION}_SHA256SUMS" \
  "https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_SHA256SUMS"

grep "consul_$${CONSUL_VERSION}_linux_amd64.zip" \
  "consul_$${CONSUL_VERSION}_SHA256SUMS" \
  | sha256sum -c -

unzip -o "consul_$${CONSUL_VERSION}_linux_amd64.zip" -d /usr/local/bin

chmod 0755 /usr/local/bin/consul

consul version

echo "Creating Consul user..."

id consul >/dev/null 2>&1 || \
  useradd \
    --system \
    --home /etc/consul.d \
    --shell /bin/false \
    consul

mkdir -p /etc/consul.d
mkdir -p /opt/consul

chown -R consul:consul /etc/consul.d
chown -R consul:consul /opt/consul

echo "Writing Consul configuration..."

cat > /etc/consul.d/consul.hcl <<EOF_CONSUL
datacenter = "acumen"

node_name = "$${NODE_NAME}"

server = true

bootstrap_expect = 3

data_dir = "/opt/consul"

bind_addr = "$${PRIVATE_IP}"

advertise_addr = "$${PRIVATE_IP}"

client_addr = "0.0.0.0"

retry_join = [
%{ for ip in cluster_private_ips ~}
  "${ip}",
%{ endfor ~}
]

encrypt = "$${CONSUL_GOSSIP_KEY}"

ui_config {
  enabled = true
}

log_level = "INFO"
EOF_CONSUL

chown consul:consul /etc/consul.d/consul.hcl
chmod 0640 /etc/consul.d/consul.hcl

echo "Creating Consul systemd service..."

cat > /etc/systemd/system/consul.service <<'EOF_CONSUL_SERVICE'
[Unit]
Description=HashiCorp Consul
Documentation=https://developer.hashicorp.com/consul
Requires=network-online.target
After=network-online.target

[Service]
User=consul
Group=consul

ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d

ExecReload=/bin/kill -HUP $MAINPID

KillSignal=SIGINT

Restart=on-failure
RestartSec=5

LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF_CONSUL_SERVICE

systemctl daemon-reload
systemctl enable consul
systemctl start consul

echo "Waiting for Consul..."

for i in {1..60}; do
  if curl -fsS http://127.0.0.1:8500/v1/status/leader >/dev/null 2>&1; then
    echo "Consul HTTP API is available."
    break
  fi

  sleep 5
done

echo "Consul status:"
systemctl --no-pager --full status consul || true

echo "Consul members:"
consul members || true

echo "Installing Nomad $${NOMAD_VERSION}..."

cd /tmp

curl -fsSLo "nomad_$${NOMAD_VERSION}_linux_amd64.zip" \
  "https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_amd64.zip"

curl -fsSLo "nomad_$${NOMAD_VERSION}_SHA256SUMS" \
  "https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_SHA256SUMS"

grep "nomad_$${NOMAD_VERSION}_linux_amd64.zip" \
  "nomad_$${NOMAD_VERSION}_SHA256SUMS" \
  | sha256sum -c -

unzip -o "nomad_$${NOMAD_VERSION}_linux_amd64.zip" -d /usr/local/bin

chmod 0755 /usr/local/bin/nomad

nomad version

echo "Creating Nomad user..."

id nomad >/dev/null 2>&1 || \
  useradd \
    --system \
    --home /etc/nomad.d \
    --shell /bin/false \
    nomad

mkdir -p /etc/nomad.d
mkdir -p /opt/nomad

chown -R nomad:nomad /etc/nomad.d
chown -R nomad:nomad /opt/nomad

usermod -aG docker nomad

echo "Writing Nomad configuration..."

cat > /etc/nomad.d/nomad.hcl <<EOF_NOMAD
region = "global"

datacenter = "acumen"

name = "$${NODE_NAME}"

data_dir = "/opt/nomad"

bind_addr = "$${PRIVATE_IP}"

advertise {
  http = "$${PRIVATE_IP}"
  rpc  = "$${PRIVATE_IP}"
  serf = "$${PRIVATE_IP}"
}

server {
  enabled = true

  bootstrap_expect = 3

  server_join {
    retry_join = [
%{ for ip in cluster_private_ips ~}
      "${ip}:4648",
%{ endfor ~}
    ]

    retry_interval = "15s"
  }
}

client {
  enabled = true
}

consul {
  address = "127.0.0.1:8500"

  server_auto_join = true

  client_auto_join = true

  auto_advertise = true
}

plugin "docker" {
  config {
    endpoint = "unix:///var/run/docker.sock"
  }
}
EOF_NOMAD

chown -R nomad:nomad /etc/nomad.d
chown -R nomad:nomad /opt/nomad

chmod 0640 /etc/nomad.d/nomad.hcl

echo "Creating Nomad systemd service..."

cat > /etc/systemd/system/nomad.service <<'EOF_NOMAD_SERVICE'
[Unit]
Description=HashiCorp Nomad
Documentation=https://developer.hashicorp.com/nomad
Requires=network-online.target docker.service consul.service
After=network-online.target docker.service consul.service

[Service]
User=root
Group=root

ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d

ExecReload=/bin/kill -HUP $MAINPID

KillSignal=SIGINT

Restart=on-failure
RestartSec=5

LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF_NOMAD_SERVICE

systemctl daemon-reload
systemctl enable nomad
systemctl start nomad

echo "Configuring dnsmasq..."

cat > /etc/dnsmasq.d/acumen-consul.conf <<'EOF_DNSMASQ'
server=/consul/127.0.0.1#8600
listen-address=127.0.0.1
bind-interfaces
cache-size=1000
EOF_DNSMASQ

systemctl enable dnsmasq
systemctl restart dnsmasq

echo "Testing local Consul DNS..."

dig @127.0.0.1 -p 8600 consul.service.consul || true

echo "Testing dnsmasq forwarding..."

dig @127.0.0.1 consul.service.consul || true

echo "============================================"
echo "Acumen cluster bootstrap completed"
echo "Node: $${NODE_NAME}"
echo "Private IP: $${PRIVATE_IP}"
echo "============================================"

touch /opt/acumen/bootstrap/complete

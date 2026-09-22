# Acumen Infrastructure Migration

Terraform-managed AWS infrastructure for a highly available HashiStack platform using **Consul, Nomad, dnsmasq, AWS Systems Manager, and GitHub Actions self-hosted runners**.

The project provisions the infrastructure automatically and validates the resulting platform by checking cluster membership, leader election, service discovery, workload scheduling, container execution, and network connectivity.

---

## Architecture

```text
                              AWS
                               │
                    ┌──────────▼──────────┐
                    │        VPC           │
                    │     10.20.0.0/16     │
                    └──────────┬───────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                 │
        Public Subnet                     Private Subnets
              │                                 │
        ┌─────▼─────┐               ┌───────────┼───────────┐
        │  Bastion  │               │           │           │
        │ 10.20.1.x │               ▼           ▼           ▼
        └───────────┘           Node 1       Node 2       Node 3
                                10.20.21.10  10.20.22.10  10.20.23.10
                                    │            │            │
                                    ├────────────┼────────────┤
                                    │            │            │
                                  Consul       Consul       Consul
                                  Nomad        Nomad        Nomad
                                    │            │            │
                                    └────────────┼────────────┘
                                                 │
                                          Nomad Scheduler
                                                 │
                                                 ▼
                                           Application
                                            Workloads
```

### Core components

| Component             | Purpose                                                    |
| --------------------- | ---------------------------------------------------------- |
| AWS VPC               | Isolated network environment                               |
| Public subnet         | Bastion and NAT connectivity                               |
| Private subnets       | HashiStack cluster nodes                                   |
| NAT Gateway           | Outbound internet access for private nodes                 |
| Bastion               | Administrative access point                                |
| AWS SSM               | Secure remote administration without direct SSH dependency |
| Consul                | Service discovery and cluster membership                   |
| Nomad                 | Workload scheduling and orchestration                      |
| dnsmasq               | Local DNS forwarding to Consul                             |
| GitHub Actions Runner | Self-hosted CI/CD execution on the cluster                 |

---

## Infrastructure

The environment is provisioned using **Terraform**.

### AWS resources

The infrastructure includes:

* VPC
* Internet Gateway
* Public and private subnets
* Route tables
* NAT Gateway
* Elastic IP
* Bastion host
* Three private cluster nodes
* Security groups
* IAM roles and instance profiles
* AWS Systems Manager integration
* GitHub Actions self-hosted runner registration

### High-availability design

The three cluster nodes are distributed across separate Availability Zones:

```text
us-east-1a → acumen-node-1
us-east-1b → acumen-node-2
us-east-1c → acumen-node-3
```

This provides multi-AZ placement for the Consul and Nomad control planes.

---

## Consul

Consul provides service discovery and cluster membership.

Verified cluster:

```text
acumen-node-1    10.20.21.10:8301    alive    server
acumen-node-2    10.20.22.10:8301    alive    server
acumen-node-3    10.20.23.10:8301    alive    server
```

Version:

```text
Consul 1.21.4
```

All three servers were confirmed alive in the `acumen` datacenter.

---

## Nomad

Nomad provides workload scheduling and orchestration.

Verified server cluster:

```text
acumen-node-1    alive    leader
acumen-node-2    alive
acumen-node-3    alive
```

Version:

```text
Nomad 2.0.7
```

Raft version:

```text
3
```

All three Nomad clients were also verified as:

```text
eligible    ready
```

---

## DNS and Service Discovery

dnsmasq forwards `.consul` DNS queries to the local Consul DNS interface.

Configuration:

```text
server=/consul/127.0.0.1#8600
```

The dnsmasq service was verified as active.

A live DNS lookup successfully resolved:

```text
acumen-node-1.node.consul
        ↓
10.20.21.10
```

The complete DNS path is:

```text
Client
  │
  ▼
dnsmasq :53
  │
  ▼
Consul DNS :8600
  │
  ▼
Consul service/node discovery
```

---

## GitHub Actions Self-Hosted Runner

A GitHub Actions self-hosted runner was deployed on `acumen-node-1`.

Runner labels include:

```text
self-hosted
linux
x64
acumen
nomad
```

The runner was validated with a GitHub Actions workflow that successfully executed checks for:

* Runner information
* Linux architecture
* Docker
* Nomad
* Git

This demonstrates that GitHub Actions jobs can execute directly on the Acumen infrastructure.

---

## Workload Validation

A temporary Nomad workload was deployed to validate the complete scheduling path.

Test workload:

```text
Job: acumen-test
Task: nginx
Image: nginx:alpine
```

Nomad successfully:

1. Accepted the job.
2. Created an allocation.
3. Scheduled the workload on `acumen-node-3`.
4. Downloaded the Docker image.
5. Started the nginx task.
6. Reported the deployment as healthy.
7. Served HTTP traffic successfully.

Observed allocation:

```text
Node: acumen-node-3
Address: 10.20.23.10:27423 -> 80
Status: running
Health: healthy
Restarts: 0
```

HTTP validation returned:

```text
HTTP/1.1 200 OK
Server: nginx/1.31.6
Content-Type: text/html
```

The temporary workload was subsequently stopped and removed from active execution.

---

## Validation Summary

| Validation                  | Result                |
| --------------------------- | --------------------- |
| EC2 instances               | ✅ 4/4 running         |
| AWS SSM                     | ✅ 4/4 online          |
| Consul servers              | ✅ 3/3 alive           |
| Nomad servers               | ✅ 3/3 alive           |
| Nomad leader election       | ✅ Verified            |
| Nomad clients               | ✅ 3/3 ready           |
| Consul DNS                  | ✅ Working             |
| dnsmasq                     | ✅ Active              |
| dnsmasq → Consul forwarding | ✅ Working             |
| Nomad workload scheduling   | ✅ Successful          |
| Docker workload             | ✅ Running             |
| Workload health             | ✅ Healthy             |
| HTTP connectivity           | ✅ 200 OK              |
| GitHub self-hosted runner   | ✅ Workflow successful |

---

## Terraform Workflow

Initialize Terraform:

```bash
terraform -chdir=terraform init
```

Format the configuration:

```bash
terraform -chdir=terraform fmt -recursive
```

Validate the configuration:

```bash
terraform -chdir=terraform validate
```

Review the execution plan:

```bash
terraform -chdir=terraform plan
```

Deploy:

```bash
terraform -chdir=terraform apply
```

Destroy the environment when no longer required:

```bash
terraform -chdir=terraform destroy
```

---

## Remote Administration

AWS Systems Manager is used to administer the private infrastructure.

This avoids requiring public SSH access to the private cluster nodes.

Example:

```bash
aws ssm send-command \
  --region us-east-1 \
  --instance-ids <instance-id> \
  --document-name "AWS-RunShellScript"
```

---

## Security Design

The infrastructure follows a private-cluster model:

* Cluster nodes reside in private subnets.
* Bastion access is separated from the cluster.
* Security groups restrict cluster communication to required ports.
* AWS Systems Manager provides remote administration.
* NAT provides outbound connectivity from private instances.
* GitHub runner registration uses a repository-scoped runner token.
* Sensitive Terraform variables are not committed to source control.

---

## Technologies

### Cloud

* AWS EC2
* AWS VPC
* AWS IAM
* AWS SSM
* AWS NAT Gateway
* AWS Security Groups

### Infrastructure as Code

* Terraform

### HashiStack

* Consul
* Nomad
* dnsmasq

### Containers

* Docker
* nginx

### CI/CD

* GitHub Actions
* GitHub Actions Self-Hosted Runner

### Operating System

* Ubuntu 24.04

---

## Project Outcomes

This project demonstrates practical experience with:

* Infrastructure as Code
* AWS networking
* Private subnet architecture
* Multi-AZ infrastructure
* High-availability Consul
* High-availability Nomad
* Service discovery
* DNS forwarding
* Container scheduling
* Docker workloads
* AWS Systems Manager
* GitHub Actions self-hosted runners
* Infrastructure validation
* Operational troubleshooting

The environment was validated from infrastructure provisioning through to a live container workload returning an HTTP `200 OK` response.


resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Security group for the Acumen Bastion host"
  vpc_id      = aws_vpc.acumen.id

  ingress {
    description = "SSH from trusted administrator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-bastion-sg"
  }
}

resource "aws_security_group" "cluster" {
  name        = "${local.name_prefix}-cluster-sg"
  description = "Security group for Acumen Consul and Nomad cluster"
  vpc_id      = aws_vpc.acumen.id

  #
  # SSH from Bastion
  #
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  #
  # Consul RPC
  #
  ingress {
    description = "Consul server RPC"
    from_port   = 8300
    to_port     = 8300
    protocol    = "tcp"
    self        = true
  }

  #
  # Consul LAN gossip TCP
  #
  ingress {
    description = "Consul LAN gossip TCP"
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    self        = true
  }

  #
  # Consul LAN gossip UDP
  #
  ingress {
    description = "Consul LAN gossip UDP"
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    self        = true
  }

  #
  # Consul WAN gossip TCP
  #
  ingress {
    description = "Consul WAN gossip TCP"
    from_port   = 8302
    to_port     = 8302
    protocol    = "tcp"
    self        = true
  }

  #
  # Consul WAN gossip UDP
  #
  ingress {
    description = "Consul WAN gossip UDP"
    from_port   = 8302
    to_port     = 8302
    protocol    = "udp"
    self        = true
  }

  #
  # Consul HTTP API
  #
  ingress {
    description = "Consul HTTP API"
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    self        = true
  }

  #
  # Consul DNS TCP
  #
  ingress {
    description = "Consul DNS TCP"
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    self        = true
  }

  #
  # Consul DNS UDP
  #
  ingress {
    description = "Consul DNS UDP"
    from_port   = 8600
    to_port     = 8600
    protocol    = "udp"
    self        = true
  }

  #
  # Nomad HTTP API
  #
  ingress {
    description = "Nomad HTTP API"
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    self        = true
  }

  #
  # Nomad RPC
  #
  ingress {
    description = "Nomad RPC"
    from_port   = 4647
    to_port     = 4647
    protocol    = "tcp"
    self        = true
  }

  #
  # Nomad Serf
  #
  ingress {
    description = "Nomad Serf"
    from_port   = 4648
    to_port     = 4648
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Nomad Serf UDP"
    from_port   = 4648
    to_port     = 4648
    protocol    = "udp"
    self        = true
  }

  #
  # DNS through dnsmasq
  #
  ingress {
    description = "DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    self        = true
  }

  #
  # Allow all traffic between Acumen nodes.
  #
  # This simplifies the initial HashiStack cluster implementation.
  #
  ingress {
    description = "Internal Acumen node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  #
  # Outbound internet through NAT Gateway
  #
  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-cluster-sg"
  }
}

resource "random_password" "consul_gossip" {
  length  = 32
  special = false
}

locals {
  cluster_nodes = {
    node1 = {
      name       = "acumen-node-1"
      subnet_id  = aws_subnet.private_a.id
      private_ip = "10.20.21.10"
      az         = data.aws_availability_zones.available.names[0]
    }

    node2 = {
      name       = "acumen-node-2"
      subnet_id  = aws_subnet.private_b.id
      private_ip = "10.20.22.10"
      az         = data.aws_availability_zones.available.names[1]
    }

    node3 = {
      name       = "acumen-node-3"
      subnet_id  = aws_subnet.private_c.id
      private_ip = "10.20.23.10"
      az         = data.aws_availability_zones.available.names[2]
    }
  }

  cluster_private_ips = [
    for node in local.cluster_nodes : node.private_ip
  ]
}

resource "aws_instance" "acumen_node" {
  for_each = local.cluster_nodes

  ami = data.aws_ssm_parameter.ubuntu_ami.value

  instance_type = var.instance_type

  subnet_id = each.value.subnet_id

  private_ip = each.value.private_ip

  vpc_security_group_ids = [
    aws_security_group.cluster.id
  ]

  key_name = var.ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.acumen_ec2.name

  associate_public_ip_address = false

  user_data = templatefile(
    "${path.module}/templates/cluster.sh",
    {
      node_name           = each.value.name
      private_ip          = each.value.private_ip
      consul_version      = var.consul_version
      nomad_version       = var.nomad_version
      consul_gossip_key   = base64encode(random_password.consul_gossip.result)
      cluster_private_ips = local.cluster_private_ips
    }
  )

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = each.value.name
    Role = "acumen-cluster"
  }
}

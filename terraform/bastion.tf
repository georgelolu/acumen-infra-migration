data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "bastion" {
  ami = data.aws_ssm_parameter.ubuntu_ami.value

  instance_type = var.bastion_instance_type

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]

  key_name = var.ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.acumen_ec2.name

  associate_public_ip_address = true

  user_data = file("${path.module}/templates/bastion.sh")

  root_block_device {
    volume_size           = 8
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
    Name = "${local.name_prefix}-bastion"
    Role = "bastion"
  }
}

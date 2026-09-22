output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "environment" {
  description = "Environment"
  value       = var.environment
}

output "vpc_id" {
  description = "Acumen VPC ID"
  value       = aws_vpc.acumen.id
}

output "vpc_cidr" {
  description = "Acumen VPC CIDR"
  value       = aws_vpc.acumen.cidr_block
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]
}

output "availability_zones" {
  description = "Availability Zones used by Acumen"
  value = [
    aws_subnet.private_a.availability_zone,
    aws_subnet.private_b.availability_zone,
    aws_subnet.private_c.availability_zone
  ]
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.acumen.id
}

output "bastion_security_group_id" {
  description = "Bastion security group ID"
  value       = aws_security_group.bastion.id
}

output "cluster_security_group_id" {
  description = "Acumen cluster security group ID"
  value       = aws_security_group.cluster.id
}

output "acumen_iam_role_name" {
  description = "IAM role used by Acumen EC2 instances"
  value       = aws_iam_role.acumen_ec2.name
}

output "acumen_instance_profile_name" {
  description = "IAM instance profile used by Acumen EC2 instances"
  value       = aws_iam_instance_profile.acumen_ec2.name
}

output "bastion_instance_id" {
  description = "Acumen Bastion EC2 instance ID"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Acumen Bastion public IP"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Acumen Bastion private IP"
  value       = aws_instance.bastion.private_ip
}

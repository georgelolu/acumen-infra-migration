variable "aws_region" {
  description = "AWS region where Acumen will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "acumen"
}

variable "vpc_cidr" {
  description = "CIDR block for the Acumen VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "allowed_ssh_cidr" {
  description = "Public IP CIDR allowed to SSH into the Bastion"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be a valid CIDR block."
  }
}

variable "instance_type" {
  description = "EC2 instance type for Acumen nodes"
  type        = string
  default     = "t3.micro"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for Bastion"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "Existing AWS EC2 key pair name"
  type        = string
}

variable "consul_version" {
  description = "Consul version"
  type        = string
  default     = "1.21.4"
}

variable "nomad_version" {
  description = "Nomad version"
  type        = string
  default     = "2.0.7"
}

variable "github_runner_enabled" {
  description = "Whether to bootstrap the GitHub Actions runner"
  type        = bool
  default     = false
}

variable "github_repository" {
  description = "GitHub repository in owner/repository format"
  type        = string
  default     = ""
}

variable "github_runner_name" {
  description = "Name of the GitHub Actions self-hosted runner"
  type        = string
  default     = "acumen-node-1-runner"
}

variable "github_runner_token" {
  description = "GitHub Actions runner registration token"
  type        = string
  sensitive   = true
  default     = ""
}

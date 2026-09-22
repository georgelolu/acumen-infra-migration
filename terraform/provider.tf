provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Acumen"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

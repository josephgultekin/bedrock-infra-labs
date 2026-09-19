terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # S3 Vectors resources (aws_s3vectors_*) landed in 6.24.0.
      version = "~> 6.24"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

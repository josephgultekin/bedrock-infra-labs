variable "aws_region" {
  description = "Region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "vessel-governance-lab"
}

variable "placeholder_container_image" {
  description = <<-EOT
    Placeholder inference container image URI for the demo model package.
    SageMaker does not validate that this image exists at registration time -
    it's only checked if you ever try to deploy/host the package, which this
    lab never does. Replace with a real ECR image URI in production.
  EOT
  type        = string
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/placeholder-vessel-summarizer:1.0"
}

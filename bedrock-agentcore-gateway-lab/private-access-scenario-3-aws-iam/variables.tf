variable "aws_region" {
  description = "Region. Must support Bedrock AgentCore and the AgentCore Gateway PrivateLink endpoint."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "agentcore-gw-private"
}

variable "vpc_cidr" {
  description = "CIDR for this scenario's own non-default VPC."
  type        = string
  default     = "10.45.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ. The NAT instance lives in the first one."
  type        = list(string)
  default     = ["10.45.0.0/24", "10.45.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ. The bastion, ping Lambda, and VPC endpoint ENIs all attach here."
  type        = list(string)
  default     = ["10.45.10.0/24", "10.45.11.0/24"]
}

variable "nat_instance_type" {
  description = "Arm64 burstable instance type for the NAT instance - t4g.nano is the cheapest Graviton size."
  type        = string
  default     = "t4g.nano"
}

variable "bastion_instance_type" {
  description = <<-EOT
    Instance type for the private-subnet test bastion. t4g.micro (1GB), not
    t4g.nano (0.5GB) - `pip install boto3 requests` risks OOM/flakiness on
    the smallest size for a one-off lab instance.
  EOT
  type        = string
  default     = "t4g.micro"
}

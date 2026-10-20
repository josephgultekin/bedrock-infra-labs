variable "aws_region" {
  description = "Region. Must support Bedrock AgentCore."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "agentcore-gw-cognito"
}

variable "vpc_cidr" {
  description = "CIDR for this scenario's own non-default VPC."
  type        = string
  default     = "10.43.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ. The NAT instance lives in the first one."
  type        = list(string)
  default     = ["10.43.0.0/24", "10.43.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ. The ping Lambda tool attaches here."
  type        = list(string)
  default     = ["10.43.10.0/24", "10.43.11.0/24"]
}

variable "nat_instance_type" {
  description = "Arm64 burstable instance type for the NAT instance - t4g.nano is the cheapest Graviton size."
  type        = string
  default     = "t4g.nano"
}

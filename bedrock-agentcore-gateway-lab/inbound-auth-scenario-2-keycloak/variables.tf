variable "aws_region" {
  description = "Region. Must support Bedrock AgentCore."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "agentcore-gw-keycloak"
}

variable "vpc_cidr" {
  description = "CIDR for this scenario's own non-default VPC."
  type        = string
  default     = "10.44.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ. The NAT instance lives in the first one."
  type        = list(string)
  default     = ["10.44.0.0/24", "10.44.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ. The ping Lambda tool attaches here."
  type        = list(string)
  default     = ["10.44.10.0/24", "10.44.11.0/24"]
}

variable "nat_instance_type" {
  description = "Arm64 burstable instance type for the NAT instance - t4g.nano is the cheapest Graviton size."
  type        = string
  default     = "t4g.nano"
}

variable "keycloak_image_tag" {
  description = <<-EOT
    Tag, in this lab's own ECR repo, of the mirrored public Keycloak image.
    You must push it yourself first - see README "Run it" step 1. Defaults
    to a placeholder so the first `tofu apply` (which creates the ECR repo)
    doesn't need the image to exist yet.
  EOT
  type        = string
  default     = "placeholder"
}

variable "keycloak_admin_username" {
  description = "Bootstrap admin user created on Keycloak's first boot (KEYCLOAK_ADMIN env var)."
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Bootstrap admin password (KEYCLOAK_ADMIN_PASSWORD env var). Change the default before apply."
  type        = string
  default     = "ChangeMe-Lab-Only-1"
  sensitive   = true
}

variable "keycloak_realm_name" {
  description = "Realm created inside Keycloak for this lab."
  type        = string
  default     = "agentcore-gateway-lab"
}

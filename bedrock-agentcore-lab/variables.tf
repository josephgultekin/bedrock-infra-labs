variable "aws_region" {
  description = "Region. Must support Bedrock AgentCore for the chosen foundation model."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "bedrock-agentcore-lab"
}

variable "vpc_cidr" {
  description = "CIDR for the lab's own non-default VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ. The NAT instance lives in the first one."
  type        = list(string)
  default     = ["10.42.0.0/24", "10.42.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ. Lambda tools and the AgentCore Runtime attach here."
  type        = list(string)
  default     = ["10.42.10.0/24", "10.42.11.0/24"]
}

variable "nat_instance_type" {
  description = "Arm64 burstable instance type for the NAT instance - t4g.nano is the cheapest Graviton size."
  type        = string
  default     = "t4g.nano"
}

variable "agent_image_tag" {
  description = <<-EOT
    Tag of the agent image in ECR to deploy via the AgentCore Runtime.
    Defaults to a placeholder so the first `tofu apply` (which creates the ECR
    repo) doesn't need the image to exist yet. Re-apply with the real tag
    (e.g. a git SHA pushed by the GitHub Actions workflow) once it's been
    built and pushed. See README "Run it" for the two-phase apply sequence.
  EOT
  type        = string
  default     = "placeholder"
}

variable "sample_tool_api_key" {
  description = <<-EOT
    Demo value stored in AgentCore Identity's API key credential provider,
    fetched by the get_order_status Lambda to prove the Identity wiring
    end-to-end. Not a real external API key - replace only if you wire this
    lab up to an actual third-party API.
  EOT
  type        = string
  default     = "demo-placeholder-api-key"
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub \"owner/repo\" slug allowed to assume the image-push role via OIDC."
  type        = string
  default     = "josephgultekin/bedrock-infra-labs"
}

variable "create_github_oidc_provider" {
  description = <<-EOT
    Whether to create the token.actions.githubusercontent.com OIDC provider.
    This is an ACCOUNT-WIDE SINGLETON - creating a second one in an account
    that already has it fails. Run
    `aws iam list-open-id-connect-providers --profile dops` first; if one
    already exists, set this to false and pass its ARN via
    existing_github_oidc_provider_arn instead.
  EOT
  type        = bool
  default     = false
}

variable "existing_github_oidc_provider_arn" {
  description = "ARN of an already-existing GitHub OIDC provider, used when create_github_oidc_provider = false."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "Region. Must support Bedrock Agents for the chosen foundation model."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "container-booking-agent-lab"
}

variable "foundation_model_id" {
  description = "Bedrock model the agent uses for orchestration."
  type        = string
  default     = "anthropic.claude-3-5-haiku-20241022-v1:0"
}

variable "aws_region" {
  description = "Region. Must be a Bedrock Guardrails-supported region."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "claims-guardrail-lab"
}

variable "bedrock_model_id" {
  description = "Bedrock cross-region inference profile ID to invoke. Haiku keeps per-call cost minimal. This model only supports on-demand invocation via an inference profile, not a bare foundation-model ID."
  type        = string
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

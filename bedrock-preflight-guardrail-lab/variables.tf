variable "aws_region" {
  description = "Region. Must be a Bedrock Guardrails-supported region."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "study-assistant-preflight-lab"
}

variable "bedrock_model_id" {
  description = "Bedrock model the responder invokes only after preflight approval."
  type        = string
  default     = "anthropic.claude-3-5-haiku-20241022-v1:0"
}

variable "demo_school_id" {
  description = "school_id used for the seeded demo phrase-policy row."
  type        = string
  default     = "school-001"
}

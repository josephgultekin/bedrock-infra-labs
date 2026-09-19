variable "aws_region" {
  description = "Workload region. All resources (logging destinations included) stay in this single region/account, per the exam requirement."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "pharmacovigilance-prompt-gov-lab"
}

variable "model_id" {
  description = "Bedrock foundation model (or inference profile ID) the prompt variant runs against."
  type        = string
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

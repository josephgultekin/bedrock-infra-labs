variable "aws_region" {
  description = "AWS region to deploy into. Must have Bedrock model access enabled for the models below."
  type        = string
  default     = "us-east-1"
}

variable "function_name" {
  description = "Name for the Lambda function"
  type        = string
  default     = "bedrock-request-format-lab"
}

variable "embedding_model_id" {
  description = "Bedrock model ID for Titan Text Embeddings V2"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "claude_model_id" {
  description = "Bedrock model ID for Claude 3.5 Sonnet (direct on-demand ID; swap for a cross-Region inference profile ARN if your account requires one)"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

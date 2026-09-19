variable "aws_region" {
  description = "Region with access to the chosen Bedrock model."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "rebooking-guidance-latency-lab"
}

variable "model_id" {
  description = "Bedrock foundation model ID used for both streaming and non-streaming calls."
  type        = string
  default     = "anthropic.claude-3-5-haiku-20241022-v1:0"
}

variable "ttft_alarm_threshold_ms" {
  description = "p90 TimeToFirstToken threshold (ms) above which the initial-delay alarm fires."
  type        = number
  default     = 3000
}

variable "total_latency_alarm_threshold_ms" {
  description = "p90 InvocationLatency threshold (ms) above which the total-duration alarm fires."
  type        = number
  default     = 15000
}

variable "alert_email" {
  description = "Optional email to subscribe to the latency alarms. Leave blank to skip."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "Region. Comprehend's synchronous Detect* APIs and PII redaction jobs are both broadly available; check current regional availability if you pick something other than the default."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "comprehend-insights-lab"
}

variable "default_language_code" {
  description = "Fallback LanguageCode passed to Detect* calls when the dominant-language detection returns a language a given API doesn't support."
  type        = string
  default     = "en"
}

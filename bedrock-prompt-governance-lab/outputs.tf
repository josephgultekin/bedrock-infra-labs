output "prompt_arn" {
  value = aws_bedrockagent_prompt.adverse_event_summary.arn
}

output "initial_version_arn" {
  value = awscc_bedrock_prompt_version.initial_release.arn
}

output "current_version_arn" {
  description = "Latest immutable prompt version - use this in PROMPT_VERSION_ARN, not initial_version_arn (that one is frozen on the now-EOL model)."
  value       = awscc_bedrock_prompt_version.inference_config_fix_release.arn
}

output "source_bucket" {
  value = aws_s3_bucket.source_prompts.bucket
}

output "source_prompt_key" {
  value = aws_s3_object.adverse_event_summary_v1.key
}

output "invocation_log_group" {
  value = aws_cloudwatch_log_group.invocation_logs.name
}

output "cloudtrail_name" {
  value = aws_cloudtrail.this.name
}

output "prompt_governance_lab_policy_arn" {
  description = "Attach this policy to whatever identity runs scripts/*.py"
  value       = aws_iam_policy.prompt_governance_lab.arn
}

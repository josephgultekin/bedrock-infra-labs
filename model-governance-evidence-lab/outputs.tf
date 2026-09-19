output "model_package_group_name" {
  value = aws_sagemaker_model_package_group.this.model_package_group_name
}

output "model_package_arn" {
  value = awscc_sagemaker_model_package.this.model_package_arn
}

output "glue_database_name" {
  value = aws_glue_catalog_database.this.name
}

output "glue_crawler_name" {
  value = aws_glue_crawler.incidents.name
}

output "source_data_bucket" {
  value = aws_s3_bucket.source_data.bucket
}

output "runtime_events_log_group" {
  value = aws_cloudwatch_log_group.runtime_events.name
}

output "governance_pipeline_policy_arn" {
  description = "Attach this policy to whatever identity runs scripts/*.py"
  value       = aws_iam_policy.governance_pipeline.arn
}

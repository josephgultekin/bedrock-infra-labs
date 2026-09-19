output "docs_bucket" {
  description = "Upload sample text files under incoming/ here to trigger the analyzer Lambda."
  value       = aws_s3_bucket.docs.bucket
}

output "analyzer_function_name" {
  value = aws_lambda_function.analyzer.function_name
}

output "comprehend_data_access_role_arn" {
  description = "Pass this as DataAccessRoleArn to start_pii_entities_detection_job."
  value       = aws_iam_role.comprehend_data_access.arn
}

output "lambda_log_group" {
  value = aws_cloudwatch_log_group.lambda.name
}

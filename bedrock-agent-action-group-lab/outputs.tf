output "agent_id" {
  value = aws_bedrockagent_agent.this.agent_id
}

output "agent_arn" {
  value = aws_bedrockagent_agent.this.agent_arn
}

output "booking_validator_function_name" {
  value = aws_lambda_function.booking_validator.function_name
}

output "mock_scheduling_api_function_name" {
  value = aws_lambda_function.mock_scheduling_api.function_name
}

output "openapi_schema_s3_uri" {
  value = "s3://${aws_s3_bucket.schema.bucket}/${aws_s3_object.openapi_schema.key}"
}

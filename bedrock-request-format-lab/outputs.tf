output "function_name" {
  value = aws_lambda_function.request_format_lab.function_name
}

output "function_arn" {
  value = aws_lambda_function.request_format_lab.arn
}

output "invoke_cli_example" {
  value = "aws lambda invoke --function-name ${aws_lambda_function.request_format_lab.function_name} --cli-binary-format raw-in-base64-out --payload file://test-events/correct-embedding.json out.json && cat out.json"
}

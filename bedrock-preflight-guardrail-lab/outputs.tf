output "api_invoke_url" {
  description = "POST here with a JSON body like {\"school_id\": \"school-001\", \"message\": \"...\"}"
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/ask"
}

output "phrase_policy_table" {
  value = aws_dynamodb_table.phrase_policies.name
}

output "moderation_audit_table" {
  value = aws_dynamodb_table.moderation_audit.name
}

output "guardrail_id" {
  value = aws_bedrock_guardrail.preflight.guardrail_id
}

output "demo_school_id" {
  value = var.demo_school_id
}

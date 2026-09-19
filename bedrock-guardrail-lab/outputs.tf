output "api_invoke_url" {
  description = "POST here with a JSON body like {\"message\": \"...\"}"
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/draft-correspondence"
}

output "audit_bucket" {
  value = aws_s3_bucket.audit.bucket
}

output "guardrail_id" {
  value = aws_bedrock_guardrail.this.guardrail_id
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.compliance_review.arn
}

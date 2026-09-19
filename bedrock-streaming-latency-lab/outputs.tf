output "model_id" {
  value = var.model_id
}

output "dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.this.dashboard_name}"
}

output "streaming_lab_policy_arn" {
  description = "Attach this policy to whatever identity runs scripts/*.py"
  value       = aws_iam_policy.streaming_lab.arn
}

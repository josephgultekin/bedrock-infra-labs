# Not attached to anything automatically - attach to whatever identity runs
# scripts/*.py.
resource "aws_iam_policy" "streaming_lab" {
  name        = "${var.project_name}-policy"
  description = "Permissions to run the streaming-vs-non-streaming comparison scripts."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeModelBothModes"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.model_id}"
      },
      {
        # CloudWatch's metric-read APIs don't support resource-level ARNs.
        Sid      = "ReadCloudWatchMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:GetMetricData", "cloudwatch:GetMetricStatistics", "cloudwatch:ListMetrics"]
        Resource = "*"
      }
    ]
  })
}

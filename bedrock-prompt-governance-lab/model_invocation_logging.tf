resource "aws_cloudwatch_log_group" "invocation_logs" {
  name              = "/bedrock/${var.project_name}/model-invocations"
  retention_in_days = 30
}

resource "aws_iam_role" "bedrock_logging" {
  name = "${var.project_name}-bedrock-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_logging" {
  name = "${var.project_name}-bedrock-logging-policy"
  role = aws_iam_role.bedrock_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "WriteInvocationLogs"
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.invocation_logs.arn}:*"
    }]
  })
}

# This is the setting that makes the exam's cross-Region S3 answer wrong:
# the destination here (the log group above) is necessarily in this same
# account and this same var.aws_region - Bedrock model invocation logging
# does not support a cross-Region or cross-account destination.
resource "aws_bedrock_model_invocation_logging_configuration" "this" {
  logging_config {
    embedding_data_delivery_enabled = false
    image_data_delivery_enabled     = false
    text_data_delivery_enabled      = true

    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.invocation_logs.name
      role_arn       = aws_iam_role.bedrock_logging.arn
    }
  }

  depends_on = [aws_iam_role_policy.bedrock_logging]
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/build/lambda.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-processor"
  retention_in_days = 7 # short retention keeps CloudWatch storage cost negligible
}

resource "aws_lambda_function" "processor" {
  function_name    = "${var.project_name}-processor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      AUDIT_BUCKET     = aws_s3_bucket.audit.bucket
      GUARDRAIL_ID     = aws_bedrock_guardrail.this.guardrail_id
      GUARDRAIL_VERSION = aws_bedrock_guardrail_version.this.version
      MODEL_ID         = var.bedrock_model_id
      EVENT_BUS_NAME   = aws_cloudwatch_event_bus.compliance.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

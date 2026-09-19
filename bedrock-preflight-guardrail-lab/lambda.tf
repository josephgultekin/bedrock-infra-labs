data "archive_file" "preflight_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/preflight"
  output_path = "${path.module}/build/preflight.zip"
}

data "archive_file" "responder_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/responder"
  output_path = "${path.module}/build/responder.zip"
}

resource "aws_cloudwatch_log_group" "preflight" {
  name              = "/aws/lambda/${var.project_name}-preflight"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "responder" {
  name              = "/aws/lambda/${var.project_name}-responder"
  retention_in_days = 7
}

resource "aws_lambda_function" "responder" {
  function_name    = "${var.project_name}-responder"
  role             = aws_iam_role.responder_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.responder_zip.output_path
  source_code_hash = data.archive_file.responder_zip.output_base64sha256

  environment {
    variables = {
      MODEL_ID = var.bedrock_model_id
    }
  }

  depends_on = [aws_cloudwatch_log_group.responder]
}

resource "aws_lambda_function" "preflight" {
  function_name    = "${var.project_name}-preflight"
  role             = aws_iam_role.preflight_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 15
  memory_size      = 256
  filename         = data.archive_file.preflight_zip.output_path
  source_code_hash = data.archive_file.preflight_zip.output_base64sha256

  environment {
    variables = {
      PHRASE_TABLE            = aws_dynamodb_table.phrase_policies.name
      AUDIT_TABLE              = aws_dynamodb_table.moderation_audit.name
      GUARDRAIL_ID             = aws_bedrock_guardrail.preflight.guardrail_id
      GUARDRAIL_VERSION        = aws_bedrock_guardrail_version.preflight.version
      RESPONDER_FUNCTION_NAME  = aws_lambda_function.responder.function_name
      POLICY_VERSION           = "1"
    }
  }

  depends_on = [aws_cloudwatch_log_group.preflight]
}

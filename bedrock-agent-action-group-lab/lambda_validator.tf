data "archive_file" "booking_validator_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/booking_validator"
  output_path = "${path.module}/build/booking_validator.zip"
}

resource "aws_iam_role" "booking_validator_exec" {
  name = "${var.project_name}-validator-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "booking_validator_basic_logs" {
  role       = aws_iam_role.booking_validator_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "booking_validator_invoke_downstream" {
  name = "${var.project_name}-validator-invoke-downstream"
  role = aws_iam_role.booking_validator_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "InvokeMockSchedulingApiOnlyAfterValidation"
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.mock_scheduling_api.arn
    }]
  })
}

resource "aws_cloudwatch_log_group" "booking_validator" {
  name              = "/aws/lambda/${var.project_name}-booking-validator"
  retention_in_days = 7
}

resource "aws_lambda_function" "booking_validator" {
  function_name    = "${var.project_name}-booking-validator"
  role             = aws_iam_role.booking_validator_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.booking_validator_zip.output_path
  source_code_hash = data.archive_file.booking_validator_zip.output_base64sha256

  environment {
    variables = {
      SCHEDULING_API_FUNCTION_NAME = aws_lambda_function.mock_scheduling_api.function_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.booking_validator]
}

# Lets Bedrock's agent runtime invoke this specific function, scoped to this
# specific agent - not a blanket "any Bedrock agent can call this" grant.
resource "aws_lambda_permission" "allow_bedrock_invoke" {
  statement_id  = "AllowBedrockAgentInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.booking_validator.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.this.agent_arn
}

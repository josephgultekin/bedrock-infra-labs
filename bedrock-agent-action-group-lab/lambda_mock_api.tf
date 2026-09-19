data "archive_file" "mock_scheduling_api_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/mock_scheduling_api"
  output_path = "${path.module}/build/mock_scheduling_api.zip"
}

resource "aws_iam_role" "mock_scheduling_api_exec" {
  name = "${var.project_name}-mock-api-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "mock_scheduling_api_basic_logs" {
  role       = aws_iam_role.mock_scheduling_api_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "mock_scheduling_api" {
  name              = "/aws/lambda/${var.project_name}-mock-scheduling-api"
  retention_in_days = 7
}

resource "aws_lambda_function" "mock_scheduling_api" {
  function_name    = "${var.project_name}-mock-scheduling-api"
  role             = aws_iam_role.mock_scheduling_api_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.mock_scheduling_api_zip.output_path
  source_code_hash = data.archive_file.mock_scheduling_api_zip.output_base64sha256

  depends_on = [aws_cloudwatch_log_group.mock_scheduling_api]
}

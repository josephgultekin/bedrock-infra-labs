data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/analyzer"
  output_path = "${path.module}/build/analyzer.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-analyzer"
  retention_in_days = 7 # short retention keeps CloudWatch storage cost negligible
}

resource "aws_lambda_function" "analyzer" {
  function_name    = "${var.project_name}-analyzer"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      INSIGHTS_PREFIX       = "insights/"
      DEFAULT_LANGUAGE_CODE = var.default_language_code
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id   = "AllowS3Invoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.analyzer.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.docs.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "incoming_docs" {
  bucket = aws_s3_bucket.docs.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.analyzer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "incoming/"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

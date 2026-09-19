terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# --- Package the Lambda source into a zip automatically ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/build/lambda.zip"
}

# --- IAM role the Lambda function assumes ---
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# --- Basic CloudWatch Logs permissions ---
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Scoped Bedrock InvokeModel permission (only the two models this lab uses) ---
resource "aws_iam_role_policy" "bedrock_invoke" {
  name = "${var.function_name}-bedrock-invoke"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel"
      ]
      Resource = [
        "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.embedding_model_id}",
        "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.claude_model_id}"
      ]
    }]
  })
}

# --- The Lambda function itself ---
resource "aws_lambda_function" "request_format_lab" {
  function_name    = var.function_name
  role              = aws_iam_role.lambda_role.arn
  handler           = "handler.lambda_handler"
  runtime           = "python3.12"
  timeout           = 30
  memory_size       = 256
  filename          = data.archive_file.lambda_zip.output_path
  source_code_hash  = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      EMBEDDING_MODEL_ID = var.embedding_model_id
      CLAUDE_MODEL_ID     = var.claude_model_id
    }
  }
}

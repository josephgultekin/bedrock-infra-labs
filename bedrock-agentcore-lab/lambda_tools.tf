# ---------- list_products ----------

data "archive_file" "list_products_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/list_products"
  output_path = "${path.module}/build/list_products.zip"
}

resource "aws_iam_role" "list_products_exec" {
  name = "${var.project_name}-list-products-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "list_products_basic_logs" {
  role       = aws_iam_role.list_products_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "list_products_vpc_access" {
  role       = aws_iam_role.list_products_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_cloudwatch_log_group" "list_products" {
  name              = "/aws/lambda/${var.project_name}-list-products"
  retention_in_days = 7 # short retention keeps CloudWatch storage cost negligible
}

resource "aws_lambda_function" "list_products" {
  function_name    = "${var.project_name}-list-products"
  role             = aws_iam_role.list_products_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 256
  filename         = data.archive_file.list_products_zip.output_path
  source_code_hash = data.archive_file.list_products_zip.output_base64sha256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.private_compute.id]
  }

  depends_on = [aws_cloudwatch_log_group.list_products]
}

# ---------- get_order_status ----------
#
# Also calls AgentCore Identity's GetResourceApiKey to fetch the demo
# credential registered in identity.tf, proving the Identity wiring works.
# NOTE (unverified - see README): the exact boto3 client/operation name for
# this call couldn't be confirmed against live AWS docs from this sandbox -
# double-check against the bedrock-agentcore-control / data-plane SDK
# reference before relying on this.

data "archive_file" "get_order_status_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/get_order_status"
  output_path = "${path.module}/build/get_order_status.zip"
}

resource "aws_iam_role" "get_order_status_exec" {
  name = "${var.project_name}-get-order-status-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "get_order_status_basic_logs" {
  role       = aws_iam_role.get_order_status_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "get_order_status_vpc_access" {
  role       = aws_iam_role.get_order_status_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "get_order_status_fetch_credential" {
  name = "${var.project_name}-get-order-status-fetch-credential"
  role = aws_iam_role.get_order_status_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "FetchDemoApiKeyFromIdentity"
      Effect   = "Allow"
      Action   = ["bedrock-agentcore:GetResourceApiKey"]
      Resource = aws_bedrockagentcore_api_key_credential_provider.sample_tool.credential_provider_arn
    }]
  })
}

resource "aws_cloudwatch_log_group" "get_order_status" {
  name              = "/aws/lambda/${var.project_name}-get-order-status"
  retention_in_days = 7
}

resource "aws_lambda_function" "get_order_status" {
  function_name    = "${var.project_name}-get-order-status"
  role             = aws_iam_role.get_order_status_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 256
  filename         = data.archive_file.get_order_status_zip.output_path
  source_code_hash = data.archive_file.get_order_status_zip.output_base64sha256

  environment {
    variables = {
      CREDENTIAL_PROVIDER_ARN = aws_bedrockagentcore_api_key_credential_provider.sample_tool.credential_provider_arn
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.private_compute.id]
  }

  depends_on = [aws_cloudwatch_log_group.get_order_status]
}

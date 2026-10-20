data "archive_file" "ping_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/ping"
  output_path = "${path.module}/build/ping.zip"
}

resource "aws_iam_role" "ping_exec" {
  name = "${var.project_name}-ping-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ping_basic_logs" {
  role       = aws_iam_role.ping_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ping_vpc_access" {
  role       = aws_iam_role.ping_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_cloudwatch_log_group" "ping" {
  name              = "/aws/lambda/${var.project_name}-ping"
  retention_in_days = 7 # short retention keeps CloudWatch storage cost negligible
}

resource "aws_lambda_function" "ping" {
  function_name    = "${var.project_name}-ping"
  role             = aws_iam_role.ping_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 256
  filename         = data.archive_file.ping_zip.output_path
  source_code_hash = data.archive_file.ping_zip.output_base64sha256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.private_compute.id]
  }

  depends_on = [aws_cloudwatch_log_group.ping]
}

# properties_json/items_json shortcuts don't exist at this top level - see
# bedrock-agentcore-lab/gateway_targets.tf's comment. Explicit `property`
# block instead.
resource "aws_bedrockagentcore_gateway_target" "ping" {
  gateway_identifier = aws_bedrockagentcore_gateway.tools.gateway_id
  name               = "ping"
  description        = "Trivial tool - proves an authenticated call reaches the Lambda behind the Gateway."

  target_configuration {
    mcp {
      lambda {
        lambda_arn = aws_lambda_function.ping.arn

        tool_schema {
          inline_payload {
            name        = "ping"
            description = "Echoes back a message. Only reachable with a valid Cognito-issued JWT."

            input_schema {
              type = "object"

              property {
                name        = "message"
                type        = "string"
                description = "Message to echo back"
                required    = false
              }
            }
          }
        }
      }
    }
  }

  credential_provider_configuration {
    gateway_iam_role {}
  }
}

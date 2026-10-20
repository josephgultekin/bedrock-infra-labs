# ---------- Gateway execution role ----------
#
# NOTE (unverified - see README, same caveat as bedrock-agentcore-lab): the
# trust principal "bedrock-agentcore.amazonaws.com" couldn't be confirmed
# against AWS's live Service Authorization Reference from this sandbox.

resource "aws_iam_role" "gateway_exec" {
  name = "${var.project_name}-gateway-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock-agentcore.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "gateway_invoke_ping_lambda" {
  name = "${var.project_name}-gateway-invoke-ping-lambda"
  role = aws_iam_role.gateway_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "InvokePingLambda"
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.ping.arn
    }]
  })
}

# ---------- Gateway ----------
#
# authorizer_type = CUSTOM_JWT is this scenario's whole point: inbound
# callers must present a valid JWT issued by the Cognito User Pool above,
# scoped to the allowed client and scope - contrast with
# bedrock-agentcore-lab's AWS_IAM gateway, which uses SigV4 instead.

resource "aws_bedrockagentcore_gateway" "tools" {
  name     = "${var.project_name}-gateway"
  role_arn = aws_iam_role.gateway_exec.arn

  authorizer_type = "CUSTOM_JWT"
  protocol_type   = "MCP"

  authorizer_configuration {
    custom_jwt_authorizer {
      discovery_url   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.this.id}/.well-known/openid-configuration"
      allowed_clients = [aws_cognito_user_pool_client.gateway_client.id]
      allowed_scopes  = ["${aws_cognito_resource_server.tools.identifier}/invoke"]
    }
  }

  protocol_configuration {
    mcp {
      instructions = "Gateway auth lab, scenario 1: Cognito-issued JWT required to call the ping tool."
    }
  }
}

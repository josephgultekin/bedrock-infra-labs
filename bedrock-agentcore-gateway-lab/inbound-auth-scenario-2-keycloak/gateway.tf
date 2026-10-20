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
# Same CUSTOM_JWT shape as scenario 1, but the discovery_url points at an
# identity provider this stack deployed (Keycloak), rather than one AWS
# provisioned for you (Cognito) - this is the "existing Identity provider
# configurations" path from the console screenshot.

resource "aws_bedrockagentcore_gateway" "tools" {
  name     = "${var.project_name}-gateway"
  role_arn = aws_iam_role.gateway_exec.arn

  authorizer_type = "CUSTOM_JWT"
  protocol_type   = "MCP"

  authorizer_configuration {
    custom_jwt_authorizer {
      discovery_url   = "https://${aws_apprunner_service.keycloak.service_url}/realms/${var.keycloak_realm_name}/.well-known/openid-configuration"
      allowed_clients = [local.gateway_client_id]
    }
  }

  protocol_configuration {
    mcp {
      instructions = "Gateway auth lab, scenario 2: Keycloak-issued JWT required to call the ping tool."
    }
  }
}

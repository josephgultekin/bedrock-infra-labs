# ---------- Gateway execution role ----------
#
# NOTE (unverified - see README, same caveat as bedrock-agentcore-lab and
# the other two scenarios): the trust principal
# "bedrock-agentcore.amazonaws.com" couldn't be confirmed against AWS's
# live Service Authorization Reference from this sandbox. (Scenario 1's
# live apply did confirm this exact principal + gateway_iam_role
# passthrough works - see its README.)

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
# authorizer_type = AWS_IAM (not CUSTOM_JWT, unlike scenarios 1/2) - the
# whole point of this scenario: SigV4 calls go through full IAM policy
# evaluation, which is what lets the bastion's aws:SourceVpce-conditioned
# permission (bastion.tf) actually enforce "only from inside this VPC".
# No policy_engine_configuration here - out of scope, adds unrelated
# surface (bedrock-agentcore-lab already covers AgentCore Policies).

resource "aws_bedrockagentcore_gateway" "tools" {
  name     = "${var.project_name}-gateway"
  role_arn = aws_iam_role.gateway_exec.arn

  authorizer_type = "AWS_IAM"
  protocol_type   = "MCP"

  protocol_configuration {
    mcp {
      instructions = "Gateway auth lab, scenario 3: SigV4-only, locked to one VPC-endpoint-scoped IAM role."
    }
  }
}

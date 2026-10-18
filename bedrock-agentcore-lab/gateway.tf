# ---------- Gateway execution role ----------
#
# NOTE (unverified - see README): the trust principal
# "bedrock-agentcore.amazonaws.com" and the permissions this role needs
# couldn't be confirmed against AWS's live Service Authorization Reference
# from this sandbox. Double-check both before `apply`.

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

resource "aws_iam_role_policy" "gateway_invoke_tool_lambdas" {
  name = "${var.project_name}-gateway-invoke-tool-lambdas"
  role = aws_iam_role.gateway_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "InvokeToolLambdas"
      Effect = "Allow"
      Action = ["lambda:InvokeFunction"]
      Resource = [
        aws_lambda_function.list_products.arn,
        aws_lambda_function.get_order_status.arn,
      ]
    }]
  })
}

# ---------- Gateway ----------

resource "aws_bedrockagentcore_gateway" "tools" {
  name     = "${var.project_name}-tools-gateway"
  role_arn = aws_iam_role.gateway_exec.arn

  # AWS_IAM keeps this lab's auth story simple - callers (the Runtime's
  # execution role) authenticate with plain SigV4, no Cognito/JWT stack
  # needed. See README for the CUSTOM_JWT alternative.
  authorizer_type = "AWS_IAM"
  protocol_type   = "MCP"

  protocol_configuration {
    mcp {
      instructions = "Sample tools lab gateway: list_products and get_order_status."
    }
  }

  # Wires this lab's AgentCore Policies component (policy.tf) directly to
  # the Gateway. NOTE (unverified - see README): `mode`'s valid values
  # weren't confirmed against live AWS docs - "ENFORCE" is this repo's best
  # guess (vs. e.g. a monitor-only mode); double-check before `apply`.
  policy_engine_configuration {
    arn  = aws_bedrockagentcore_policy_engine.this.policy_engine_arn
    mode = "ENFORCE"
  }
}

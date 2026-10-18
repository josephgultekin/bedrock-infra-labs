# ---------- Runtime execution role ----------
#
# NOTE (unverified - see README): same caveat as gateway.tf - the trust
# principal and the bedrock-agentcore:* action names below need a
# double-check against AWS's live Service Authorization Reference before
# `apply`. The ec2:*NetworkInterface* permissions may also turn out to be
# handled by an AWS service-linked role instead of needing to live on this
# execution role - confirm once you can see a real `apply` error (or lack
# thereof).

resource "aws_iam_role" "runtime_exec" {
  name = "${var.project_name}-runtime-exec"

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

resource "aws_iam_role_policy" "runtime_exec_permissions" {
  name = "${var.project_name}-runtime-exec-permissions"
  role = aws_iam_role.runtime_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PullAgentImage"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = aws_ecr_repository.agent.arn
      },
      {
        Sid = "EcrAuth"
        # GetAuthorizationToken has no resource-level permissions - it must be "*".
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "WriteRuntimeLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        # Log group names are chosen by the AgentCore service at runtime, not known in advance.
        Resource = "*"
      },
      {
        Sid = "InvokeFoundationModel"
        # Foundation models are AWS-owned, cross-account resources - there's
        # no account-scoped ARN to restrict to.
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = "*"
      },
      {
        Sid      = "InvokeToolsGateway"
        Effect   = "Allow"
        Action   = ["bedrock-agentcore:InvokeGateway"]
        Resource = aws_bedrockagentcore_gateway.tools.gateway_arn
      },
      {
        Sid      = "GetWorkloadAccessToken"
        Effect   = "Allow"
        Action   = ["bedrock-agentcore:GetWorkloadAccessToken"]
        Resource = aws_bedrockagentcore_workload_identity.agent.workload_identity_arn
      },
      {
        Sid    = "ManageVpcAttachmentEnis"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses",
        ]
        # ENI actions don't support resource-level restriction.
        Resource = "*"
      },
    ]
  })
}

# ---------- Agent Runtime ----------

resource "aws_bedrockagentcore_agent_runtime" "agent" {
  agent_runtime_name = replace(var.project_name, "-", "_")
  role_arn           = aws_iam_role.runtime_exec.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.agent.repository_url}:${var.agent_image_tag}"
    }
  }

  network_configuration {
    network_mode = "VPC"

    network_mode_config {
      subnets         = aws_subnet.private[*].id
      security_groups = [aws_security_group.private_compute.id]
    }
  }

  protocol_configuration {
    server_protocol = "MCP"
  }
}

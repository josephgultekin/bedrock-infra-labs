# AgentCore Gateway's own PrivateLink interface endpoint - confirmed real
# via a live fetch of AWS's docs (not inferred): service name
# "com.amazonaws.<region>.bedrock-agentcore.gateway". private_dns_enabled
# means the Gateway's normal gateway_url resolves to this endpoint's
# private IPs for anything resolving it from inside this VPC - the bastion
# doesn't need a different hostname, just a different place to resolve it.
#
# The policy below is lifted directly from AWS's own documented example
# (confirmed, not a guess) - restricts the endpoint to one principal
# (the bastion's role) and one action against one specific gateway.
# This only works because this scenario's Gateway uses authorizer_type =
# AWS_IAM: AWS's docs state OAuth-authorized gateways (scenarios 1/2) are
# forced to Principal = "*" here, since OAuth callers have no IAM identity
# for this policy to restrict.

resource "aws_vpc_endpoint" "gateway" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.bedrock-agentcore.gateway"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_role.bastion.arn }
      Action    = ["bedrock-agentcore:InvokeGateway"]
      Resource  = aws_bedrockagentcore_gateway.tools.gateway_arn
    }]
  })

  tags = {
    Name = "${var.project_name}-gateway-endpoint"
  }
}

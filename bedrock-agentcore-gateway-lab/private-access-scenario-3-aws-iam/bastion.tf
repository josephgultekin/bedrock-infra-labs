# Test bastion: a private-subnet, SSM-only EC2 instance whose IAM role is
# deliberately scoped to only succeed calling the Gateway when the request
# transits the VPC endpoint above. This is the actual enforcement layer -
# see vpc_endpoint.tf's comment on why the endpoint policy alone isn't
# enough, and this README's honesty section on what this does and doesn't
# prove.
#
# NOTE (unverified - see README): the aws:SourceVpce condition key working
# this way for bedrock-agentcore:InvokeGateway specifically is a standard,
# well-established IAM pattern (used this way for S3, KMS, etc.), extended
# here to a service I haven't independently confirmed it against. Confirm
# with a live apply + scripts/run_private_test.sh before trusting this
# beyond this lab.

resource "aws_iam_role" "bastion" {
  name = "${var.project_name}-bastion"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "bastion_invoke_gateway_vpc_only" {
  name = "${var.project_name}-bastion-invoke-gateway-vpc-only"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "InvokeGatewayOnlyViaThisVpcEndpoint"
      Effect   = "Allow"
      Action   = ["bedrock-agentcore:InvokeGateway"]
      Resource = aws_bedrockagentcore_gateway.tools.gateway_arn
      Condition = {
        StringEquals = { "aws:SourceVpce" = aws_vpc_endpoint.gateway.id }
      }
    }]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-bastion"
  role = aws_iam_role.bastion.name
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  # No public IP - reachable only via SSM Session Manager (outbound-only,
  # no inbound port needed), matching this scenario's whole point.
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    pip3 install --quiet boto3 requests

    cat <<'SCRIPT' > /opt/gateway_test.py
    """
    Runs on the bastion only (see scripts/run_private_test.sh) - calls the
    AgentCore Gateway's MCP endpoint via SigV4, using this instance's own
    role credentials (picked up automatically from instance metadata).
    Proves the aws:SourceVpce-conditioned permission works from inside the
    VPC; running the identical code from outside it should fail at IAM
    authorization, not at the network layer.
    """
    import json
    import boto3
    import requests
    from botocore.auth import SigV4Auth
    from botocore.awsrequest import AWSRequest

    GATEWAY_URL = "${aws_bedrockagentcore_gateway.tools.gateway_url}"
    REGION = "${var.aws_region}"
    SERVICE_NAME = "bedrock-agentcore"


    def _signed_post(url, body):
        session = boto3.Session()
        credentials = session.get_credentials()
        request = AWSRequest(method="POST", url=url, data=json.dumps(body), headers={"Content-Type": "application/json"})
        SigV4Auth(credentials, SERVICE_NAME, REGION).add_auth(request)
        return requests.post(url, data=request.body, headers=dict(request.headers))


    def call_gateway(method, params):
        body = {"jsonrpc": "2.0", "id": "1", "method": method, "params": params}
        return _signed_post(GATEWAY_URL, body)


    def main():
        print("1. Calling tools/list (SigV4, via the VPC endpoint)...")
        response = call_gateway("tools/list", {})
        print(f"   HTTP {response.status_code}")
        print(json.dumps(response.json(), indent=2))

        print("\n2. Calling tools/call ping___ping...")
        response = call_gateway("tools/call", {"name": "ping___ping", "arguments": {"message": "hello from the bastion"}})
        print(f"   HTTP {response.status_code}")
        print(json.dumps(response.json(), indent=2))


    if __name__ == "__main__":
        main()
    SCRIPT
  EOF

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

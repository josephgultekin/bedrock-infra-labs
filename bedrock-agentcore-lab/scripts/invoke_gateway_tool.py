"""
Calls the AgentCore Gateway's MCP endpoint directly (tools/list, then
tools/call), bypassing the agent Runtime entirely - useful for checking the
Gateway -> Lambda target wiring in isolation.

The Gateway uses authorizer_type = AWS_IAM, so requests need SigV4 signing;
this script signs a plain `requests` call with botocore's SigV4Auth rather
than pulling in a full MCP client library, since AgentCore's MCP endpoint
speaks plain JSON-RPC 2.0 over HTTPS.

NOTE (unverified - see README): the JSON-RPC method names (tools/list,
tools/call) match the standard MCP spec, but AgentCore's exact
request/response envelope on top of SigV4 hasn't been confirmed against a
live call.

Setup:
    export GATEWAY_URL=$(tofu -chdir=.. output -raw gateway_url)
    export AWS_PROFILE=dops

Run:
    python3 invoke_gateway_tool.py tools/list
    python3 invoke_gateway_tool.py tools/call get_order_status '{"order_id": "ORD-1001"}'
"""

import json
import os
import sys

import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

REGION = boto3.session.Session().region_name or "us-east-1"
GATEWAY_URL = os.environ["GATEWAY_URL"]
SERVICE_NAME = "bedrock-agentcore"


def _signed_post(url, body):
    session = boto3.Session()
    credentials = session.get_credentials()
    request = AWSRequest(method="POST", url=url, data=json.dumps(body), headers={"Content-Type": "application/json"})
    SigV4Auth(credentials, SERVICE_NAME, REGION).add_auth(request)
    return requests.post(url, data=request.body, headers=dict(request.headers))


def main():
    method = sys.argv[1] if len(sys.argv) > 1 else "tools/list"
    params = {}

    if method == "tools/call":
        tool_name = sys.argv[2]
        arguments = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        params = {"name": tool_name, "arguments": arguments}

    body = {
        "jsonrpc": "2.0",
        "id": "1",
        "method": method,
        "params": params,
    }

    response = _signed_post(GATEWAY_URL, body)
    print(f"HTTP {response.status_code}")
    print(json.dumps(response.json(), indent=2))


if __name__ == "__main__":
    main()

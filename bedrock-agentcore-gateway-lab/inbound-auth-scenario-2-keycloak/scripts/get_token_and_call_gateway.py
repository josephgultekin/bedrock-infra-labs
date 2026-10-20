"""
Gets a client_credentials JWT from Keycloak, then calls the AgentCore
Gateway's MCP endpoint with it - same shape as scenario 1's script, against
a self-hosted IdP instead of Cognito.

NOTE: scenario 1's script confirmed against a live call that the
Gateway's tools/list envelope matches the standard MCP spec, and that
tools/call must address a tool by "<gateway_target_name>___<tool_name>"
(triple underscore) - here "ping___ping", since both the gateway_target
and its one tool are named "ping" (see lambda_tool.tf). Scenario 2's own
caveats about Keycloak-behind-App-Runner hostname behavior are still
unverified - if this fails, check the App Runner service logs before
assuming the script is wrong.

Setup:
    export TOKEN_ENDPOINT=$(tofu output -raw token_endpoint)
    export CLIENT_ID=$(tofu output -raw client_id)
    export CLIENT_SECRET=$(tofu output -raw client_secret)
    export GATEWAY_URL=$(tofu output -raw gateway_url)

Run:
    python3 get_token_and_call_gateway.py
"""

import json
import os

import requests

TOKEN_ENDPOINT = os.environ["TOKEN_ENDPOINT"]
CLIENT_ID = os.environ["CLIENT_ID"]
CLIENT_SECRET = os.environ["CLIENT_SECRET"]
GATEWAY_URL = os.environ["GATEWAY_URL"]


def get_token():
    response = requests.post(
        TOKEN_ENDPOINT,
        data={"grant_type": "client_credentials"},
        auth=(CLIENT_ID, CLIENT_SECRET),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    response.raise_for_status()
    return response.json()["access_token"]


def call_gateway(method, params, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    body = {"jsonrpc": "2.0", "id": "1", "method": method, "params": params}
    return requests.post(GATEWAY_URL, json=body, headers=headers)


def main():
    print("1. Calling tools/list with NO token (expect a rejection)...")
    response = call_gateway("tools/list", {})
    print(f"   HTTP {response.status_code}\n")

    print("2. Getting a valid JWT from Keycloak...")
    token = get_token()
    print(f"   Got a token ({len(token)} chars)\n")

    print("3. Calling tools/list WITH the token (expect success)...")
    response = call_gateway("tools/list", {}, token=token)
    print(f"   HTTP {response.status_code}")
    print(json.dumps(response.json(), indent=2))

    print("\n4. Calling tools/call ping WITH the token...")
    response = call_gateway("tools/call", {"name": "ping___ping", "arguments": {"message": "hello"}}, token=token)
    print(f"   HTTP {response.status_code}")
    print(json.dumps(response.json(), indent=2))


if __name__ == "__main__":
    main()

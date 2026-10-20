"""
Gets a client_credentials JWT from Cognito, then calls the AgentCore
Gateway's MCP endpoint with it - proving the CUSTOM_JWT authorizer accepts
a valid token, then proving it rejects a missing/garbage one.

NOTE: confirmed against a live call (2026-10-20) that the Gateway's
tools/list JSON-RPC envelope matches the standard MCP spec. One real
surprise: tools/call must address a tool by
"<gateway_target_name>___<tool_name>" (triple underscore), not the bare
tool name from the inline_payload - tools/list's response reveals the real
name (here, "ping___ping", since both the gateway_target and its one tool
are named "ping" - see lambda_tool.tf).

Setup:
    export TOKEN_ENDPOINT=$(tofu output -raw token_endpoint)
    export APP_CLIENT_ID=$(tofu output -raw app_client_id)
    export APP_CLIENT_SECRET=$(tofu output -raw app_client_secret)
    export SCOPE=$(tofu output -raw resource_server_identifier)/invoke
    export GATEWAY_URL=$(tofu output -raw gateway_url)

Run:
    python3 get_token_and_call_gateway.py
"""

import json
import os

import requests

TOKEN_ENDPOINT = os.environ["TOKEN_ENDPOINT"]
APP_CLIENT_ID = os.environ["APP_CLIENT_ID"]
APP_CLIENT_SECRET = os.environ["APP_CLIENT_SECRET"]
SCOPE = os.environ["SCOPE"]
GATEWAY_URL = os.environ["GATEWAY_URL"]


def get_token():
    response = requests.post(
        TOKEN_ENDPOINT,
        data={"grant_type": "client_credentials", "scope": SCOPE},
        auth=(APP_CLIENT_ID, APP_CLIENT_SECRET),
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

    print("2. Getting a valid JWT from Cognito...")
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

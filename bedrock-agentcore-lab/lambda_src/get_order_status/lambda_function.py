"""
get_order_status - AgentCore Gateway MCP tool, backed by Lambda.

Looks up a mock order's status, after first fetching the demo credential
registered in AgentCore Identity (identity.tf's api_key_credential_provider)
via GetResourceApiKey - this is what actually proves the Identity wiring
works, since the "order status" data itself is just a static mock.

NOTE: both the Gateway's event shape (see list_products' docstring) and the
boto3 client/operation name used below for GetResourceApiKey are unverified
against live AWS docs from this sandbox (see README). `boto3.client(
"bedrock-agentcore")` and `.get_resource_api_key(...)` are this repo's best
guess at the data-plane SDK shape - confirm against the installed boto3
version's service model (`python3 -c "import boto3; print(boto3.client(
'bedrock-agentcore').meta.service_model.operation_names)"`) before relying on
this in anything beyond this lab.
"""

import os

import boto3

REGION = boto3.session.Session().region_name or "us-east-1"
CREDENTIAL_PROVIDER_ARN = os.environ["CREDENTIAL_PROVIDER_ARN"]

agentcore_data_plane = boto3.client("bedrock-agentcore", region_name=REGION)

MOCK_ORDERS = {
    "ORD-1001": "shipped",
    "ORD-1002": "pending_pickup",
    "ORD-1003": "delivered",
}


def _extract_arguments(event):
    if isinstance(event, dict):
        for key in ("arguments", "input", "parameters"):
            if key in event:
                return event[key]
    return event


def _fetch_demo_credential():
    """Proves the Identity wiring: fetches the demo API key, never returns it."""
    response = agentcore_data_plane.get_resource_api_key(
        credentialProviderArn=CREDENTIAL_PROVIDER_ARN,
    )
    return "api_key" in response or "apiKey" in response


def handler(event, context):
    arguments = _extract_arguments(event) or {}
    order_id = arguments.get("order_id") if isinstance(arguments, dict) else None

    credential_fetched = False
    try:
        credential_fetched = _fetch_demo_credential()
    except Exception as exc:  # noqa: BLE001 - surfaced in the response for lab visibility
        return {"error": f"credential fetch failed: {exc}"}

    status = MOCK_ORDERS.get(order_id, "unknown_order") if order_id else "missing_order_id"

    return {
        "order_id": order_id,
        "status": status,
        "identity_credential_fetched": credential_fetched,
    }

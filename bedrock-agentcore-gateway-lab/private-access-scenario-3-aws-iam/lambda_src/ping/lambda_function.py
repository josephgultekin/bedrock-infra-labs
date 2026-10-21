"""
ping - trivial AgentCore Gateway MCP tool, backed by Lambda.

Exists purely to prove an authenticated call makes it all the way through:
Gateway auth check -> gateway_iam_role -> this Lambda. See
bedrock-agentcore-lab/lambda_src/list_products/lambda_function.py's
docstring for the same caveat about the Gateway's exact event shape.
"""


def _extract_arguments(event):
    if isinstance(event, dict):
        for key in ("arguments", "input", "parameters"):
            if key in event:
                return event[key]
    return event


def handler(event, context):
    arguments = _extract_arguments(event) or {}
    message = arguments.get("message") if isinstance(arguments, dict) else None
    return {"echo": message or "pong"}

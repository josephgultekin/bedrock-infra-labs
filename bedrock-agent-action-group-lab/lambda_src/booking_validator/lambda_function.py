"""
The Lambda executor behind the agent's action group. This is where
deterministic validation lives - required fields, ISO 8601 time parsing, and
a supported container-type enum - all enforced with plain code, independent
of anything the model decided or how it phrased the tool call. The
downstream scheduling API (mock_scheduling_api) is only ever invoked after
every check here passes.

Handles the Bedrock action-group Lambda event/response envelope directly
(messageVersion 1.0), rather than relying on any framework, so the
validation logic is easy to read end to end.
"""

import json
import os
from datetime import datetime

import boto3

lambda_client = boto3.client("lambda")

SCHEDULING_API_FUNCTION_NAME = os.environ["SCHEDULING_API_FUNCTION_NAME"]

ALLOWED_TERMINALS = {"TML-01", "TML-02", "TML-03"}
ALLOWED_CONTAINER_TYPES = {"DRY", "REEFER", "TANK", "OPEN_TOP", "FLAT_RACK"}


def _extract_params(event):
    """Pulls the flat {name: value} params out of the Bedrock action-group
    request body envelope."""
    props = (
        event.get("requestBody", {})
        .get("content", {})
        .get("application/json", {})
        .get("properties", [])
    )
    return {p["name"]: p.get("value") for p in props}


def _validate(params):
    """Returns (is_valid, error, details)."""
    terminal_id = params.get("terminal_id")
    appointment_time = params.get("appointment_time")
    container_type = params.get("container_type")

    if not terminal_id:
        return False, "missing_field", "terminal_id is required."
    if terminal_id not in ALLOWED_TERMINALS:
        return False, "invalid_terminal_id", (
            f"'{terminal_id}' is not a recognized terminal ID. "
            f"Valid terminals: {', '.join(sorted(ALLOWED_TERMINALS))}."
        )

    if not appointment_time:
        return False, "missing_field", "appointment_time is required."
    try:
        # Accept a trailing 'Z' the way most ISO 8601 producers emit it.
        datetime.fromisoformat(appointment_time.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return False, "invalid_appointment_time", (
            f"'{appointment_time}' is not a valid ISO 8601 timestamp, "
            "e.g. 2026-09-02T14:00:00Z."
        )

    if not container_type:
        return False, "missing_field", "container_type is required."
    if container_type not in ALLOWED_CONTAINER_TYPES:
        return False, "invalid_container_type", (
            f"'{container_type}' is not a supported container type. "
            f"Valid types: {', '.join(sorted(ALLOWED_CONTAINER_TYPES))}."
        )

    return True, None, None


def _response(event, http_status, body):
    return {
        "messageVersion": "1.0",
        "response": {
            "actionGroup": event.get("actionGroup"),
            "apiPath": event.get("apiPath"),
            "httpMethod": event.get("httpMethod"),
            "httpStatusCode": http_status,
            "responseBody": {"application/json": {"body": json.dumps(body)}},
        },
    }


def handler(event, context):
    params = _extract_params(event)
    is_valid, error, details = _validate(params)

    if not is_valid:
        # Rejected here. The scheduling API is never called - this is the
        # "fail predictably before it reaches the scheduling API" requirement.
        return _response(event, 400, {"error": error, "details": details})

    # Only a fully validated request reaches the downstream system.
    invoke_response = lambda_client.invoke(
        FunctionName=SCHEDULING_API_FUNCTION_NAME,
        InvocationType="RequestResponse",
        Payload=json.dumps(params).encode("utf-8"),
    )
    confirmation = json.loads(invoke_response["Payload"].read())
    return _response(event, 200, confirmation)

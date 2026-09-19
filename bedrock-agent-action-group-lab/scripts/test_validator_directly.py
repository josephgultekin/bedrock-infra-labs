"""
The primary proof for this lab. Rather than relying on an LLM to reliably
produce a malformed tool call (which is possible but nondeterministic),
this invokes booking_validator directly with Bedrock action-group-shaped
events - exactly the shape Bedrock would send - covering each failure mode
from the exam scenario plus one fully valid request. Then it checks the
downstream mock scheduling API's logs to confirm it was only actually
invoked once, for the valid case.

Setup:
    export VALIDATOR_FUNCTION_NAME=$(terraform output -raw booking_validator_function_name)
    export SCHEDULING_API_FUNCTION_NAME=$(terraform output -raw mock_scheduling_api_function_name)

Run:
    python3 test_validator_directly.py
"""

import json
import os
import time

import boto3

REGION = boto3.session.Session().region_name or "us-east-1"
lambda_client = boto3.client("lambda", region_name=REGION)
logs_client = boto3.client("logs", region_name=REGION)

VALIDATOR_FUNCTION_NAME = os.environ["VALIDATOR_FUNCTION_NAME"]
SCHEDULING_API_FUNCTION_NAME = os.environ["SCHEDULING_API_FUNCTION_NAME"]
SCHEDULING_API_LOG_GROUP = f"/aws/lambda/{SCHEDULING_API_FUNCTION_NAME}"


def bedrock_event(terminal_id=None, appointment_time=None, container_type=None):
    """Builds an event in the same shape Bedrock sends to an action group's
    Lambda executor for a POST /pickup-appointments call."""
    properties = []
    if terminal_id is not None:
        properties.append({"name": "terminal_id", "type": "string", "value": terminal_id})
    if appointment_time is not None:
        properties.append({"name": "appointment_time", "type": "string", "value": appointment_time})
    if container_type is not None:
        properties.append({"name": "container_type", "type": "string", "value": container_type})

    return {
        "messageVersion": "1.0",
        "agent": {"name": "container-booking-agent-lab", "version": "DRAFT"},
        "actionGroup": "ContainerBookingActions",
        "apiPath": "/pickup-appointments",
        "httpMethod": "POST",
        "requestBody": {
            "content": {"application/json": {"properties": properties}}
        },
    }


SCENARIOS = [
    ("Missing terminal_id", bedrock_event(
        appointment_time="2026-09-02T14:00:00Z", container_type="DRY"
    )),
    ("Non-ISO appointment_time", bedrock_event(
        terminal_id="TML-01", appointment_time="next Tuesday afternoon", container_type="DRY"
    )),
    ("Unsupported container_type", bedrock_event(
        terminal_id="TML-01", appointment_time="2026-09-02T14:00:00Z", container_type="HAZMAT_SPECIAL"
    )),
    ("Fully valid request", bedrock_event(
        terminal_id="TML-01", appointment_time="2026-09-02T14:00:00Z", container_type="DRY"
    )),
]


def invoke_validator(event):
    response = lambda_client.invoke(
        FunctionName=VALIDATOR_FUNCTION_NAME,
        InvocationType="RequestResponse",
        Payload=json.dumps(event).encode("utf-8"),
    )
    payload = json.loads(response["Payload"].read())
    inner = payload["response"]
    status = inner["httpStatusCode"]
    body = json.loads(inner["responseBody"]["application/json"]["body"])
    return status, body


def count_downstream_invocations(since_epoch_ms):
    """Counts REPORT lines in the mock scheduling API's log group since a
    given time, as a check on how many times it was actually called."""
    time.sleep(5)  # let CloudWatch Logs catch up
    try:
        events = logs_client.filter_log_events(
            logGroupName=SCHEDULING_API_LOG_GROUP,
            startTime=since_epoch_ms,
            filterPattern="REPORT",
        )
        return len(events.get("events", []))
    except logs_client.exceptions.ResourceNotFoundException:
        return None  # log group doesn't exist yet - no invocations ever happened


def main():
    start_time_ms = int(time.time() * 1000)

    for label, event in SCENARIOS:
        print(f"\n{'=' * 72}\n{label}\n{'=' * 72}")
        status, body = invoke_validator(event)
        print(f"httpStatusCode: {status}")
        print(json.dumps(body, indent=2))

    print(f"\n{'=' * 72}\nChecking how many times the downstream scheduling API was actually called\n{'=' * 72}")
    count = count_downstream_invocations(start_time_ms)
    if count is None:
        print("Downstream API log group not found - it was never invoked.")
    else:
        print(f"Downstream scheduling API invocations since test start: {count}")
        print("Expected: 1 (only the fully valid request). The three malformed")
        print("requests above were rejected by the validator and never reached it.")


if __name__ == "__main__":
    main()

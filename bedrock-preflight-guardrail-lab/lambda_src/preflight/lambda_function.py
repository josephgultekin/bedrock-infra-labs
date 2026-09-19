import hashlib
import json
import os
import time
import uuid

import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
bedrock = boto3.client("bedrock-runtime")
lambda_client = boto3.client("lambda")

PHRASE_TABLE = os.environ["PHRASE_TABLE"]
AUDIT_TABLE = os.environ["AUDIT_TABLE"]
GUARDRAIL_ID = os.environ["GUARDRAIL_ID"]
GUARDRAIL_VERSION = os.environ["GUARDRAIL_VERSION"]
RESPONDER_FUNCTION = os.environ["RESPONDER_FUNCTION_NAME"]
POLICY_VERSION = os.environ.get("POLICY_VERSION", "1")

phrase_table = dynamodb.Table(PHRASE_TABLE)
audit_table = dynamodb.Table(AUDIT_TABLE)

BLOCKED_PHRASE_MESSAGE = "This message contains content that isn't permitted by your school's policy."
BLOCKED_GUARDRAIL_MESSAGE = "This request cannot be processed due to safety policy restrictions."


def _audit(request_id, school_id, decision, message):
    # Only decision metadata and a one-way hash are ever persisted. The prompt
    # text itself - especially a rejected one - never gets written here.
    audit_table.put_item(
        Item={
            "request_id": request_id,
            "school_id": school_id,
            "decision": decision,
            "policy_version": POLICY_VERSION,
            "timestamp": int(time.time()),
            "request_hash": hashlib.sha256(message.encode("utf-8")).hexdigest(),
        }
    )


def _phrase_blocked(school_id, message):
    resp = phrase_table.query(KeyConditionExpression=Key("school_id").eq(school_id))
    lowered = message.lower()
    return any(item["phrase"].lower() in lowered for item in resp.get("Items", []))


def _reply(request_id, decision, text):
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"request_id": request_id, "decision": decision, "message": text}),
    }


def handler(event, context):
    body = json.loads(event.get("body") or "{}")
    school_id = body.get("school_id", "unknown")
    message = body.get("message", "")
    request_id = str(uuid.uuid4())

    # 1. Custom per-school policy check. Deterministic, no model involved.
    if _phrase_blocked(school_id, message):
        _audit(request_id, school_id, "BLOCKED_PHRASE", message)
        return _reply(request_id, "blocked", BLOCKED_PHRASE_MESSAGE)

    # 2. Standalone Bedrock safety evaluation via ApplyGuardrail. No foundation
    # model or agent has been invoked at this point - this is a pure content check.
    guardrail_response = bedrock.apply_guardrail(
        guardrailIdentifier=GUARDRAIL_ID,
        guardrailVersion=GUARDRAIL_VERSION,
        source="INPUT",
        content=[{"text": {"text": message}}],
    )

    if guardrail_response.get("action") == "GUARDRAIL_INTERVENED":
        _audit(request_id, school_id, "BLOCKED_GUARDRAIL", message)
        return _reply(request_id, "blocked", BLOCKED_GUARDRAIL_MESSAGE)

    # 3. Only now, after both gates pass, does model orchestration begin.
    _audit(request_id, school_id, "ALLOWED", message)
    invoke_response = lambda_client.invoke(
        FunctionName=RESPONDER_FUNCTION,
        InvocationType="RequestResponse",
        Payload=json.dumps({"request_id": request_id, "message": message}).encode("utf-8"),
    )
    payload = json.loads(invoke_response["Payload"].read())
    return _reply(request_id, "allowed", payload.get("answer", ""))

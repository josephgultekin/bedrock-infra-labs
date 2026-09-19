import json
import os
import re
import time
import uuid

import boto3

bedrock = boto3.client("bedrock-runtime")
s3 = boto3.client("s3")
events = boto3.client("events")

BUCKET = os.environ["AUDIT_BUCKET"]
GUARDRAIL_ID = os.environ["GUARDRAIL_ID"]
GUARDRAIL_VERSION = os.environ["GUARDRAIL_VERSION"]
MODEL_ID = os.environ["MODEL_ID"]
EVENT_BUS = os.environ["EVENT_BUS_NAME"]

# Minimal demo redaction. In production, prefer Amazon Comprehend PII detection
# (DetectPiiEntities) for broader, model-based coverage instead of fixed regexes.
PATTERNS = {
    "EMAIL": re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"),
    "SSN": re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
    "PHONE": re.compile(r"\b\d{3}[-.]\d{3}[-.]\d{4}\b"),
    "CLAIM_NUMBER": re.compile(r"\bCLM-\d{6,}\b"),
}


def redact(text: str) -> str:
    for label, pattern in PATTERNS.items():
        text = pattern.sub(f"[REDACTED-{label}]", text)
    return text


def handler(event, context):
    body = json.loads(event.get("body") or "{}")
    prompt = body.get("message", "")
    request_id = str(uuid.uuid4())

    response = bedrock.converse(
        modelId=MODEL_ID,
        messages=[{"role": "user", "content": [{"text": prompt}]}],
        guardrailConfig={
            "guardrailIdentifier": GUARDRAIL_ID,
            "guardrailVersion": GUARDRAIL_VERSION,
            "trace": "enabled",
        },
    )

    stop_reason = response.get("stopReason", "")
    intervened = stop_reason == "guardrail_intervened"

    message_content = response.get("output", {}).get("message", {}).get("content", [])
    model_text = "".join(block.get("text", "") for block in message_content if "text" in block)

    record = {
        "request_id": request_id,
        "timestamp": int(time.time()),
        "redacted_prompt": redact(prompt),
        "redacted_response": redact(model_text),
        "guardrail_intervened": intervened,
        "stop_reason": stop_reason,
    }

    # Only redacted evidence is ever written to the audit store.
    s3.put_object(
        Bucket=BUCKET,
        Key=f"audit/{record['timestamp']}-{request_id}.json",
        Body=json.dumps(record).encode("utf-8"),
        ContentType="application/json",
    )

    if intervened:
        events.put_events(
            Entries=[
                {
                    "Source": "claims.guardrail",
                    "DetailType": "GuardrailViolation",
                    "Detail": json.dumps(record),
                    "EventBusName": EVENT_BUS,
                }
            ]
        )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "request_id": request_id,
                "guardrail_intervened": intervened,
                "response": redact(model_text),
            }
        ),
    }

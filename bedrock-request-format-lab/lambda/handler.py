"""
Bedrock request-schema lab.

This function exists to let you FEEL the difference between the request
body shapes that different Bedrock model families expect, by deliberately
sending both correct and incorrect shapes and showing you the raw result.

Invoke with an event like:

  {"target": "embedding", "mode": "correct", "query": "termination clause"}
  {"target": "embedding", "mode": "broken_messages_format", "query": "termination clause"}
  {"target": "claude", "mode": "correct", "context": "...", "question": "..."}
  {"target": "claude", "mode": "broken_legacy_completion", "context": "...", "question": "..."}
  {"target": "claude", "mode": "broken_titan_generic_shape", "context": "...", "question": "..."}

"target" picks which model to call (Titan Text Embeddings V2, or Claude 3.5 Sonnet).
"mode" picks which request body shape to send for that model.
"""

import json
import os
import boto3
from botocore.exceptions import ClientError

bedrock_runtime = boto3.client("bedrock-runtime")

EMBEDDING_MODEL_ID = os.environ["EMBEDDING_MODEL_ID"]
CLAUDE_MODEL_ID = os.environ["CLAUDE_MODEL_ID"]


# ---------------------------------------------------------------------------
# Request body builders
# ---------------------------------------------------------------------------

def build_embedding_body(mode: str, query: str) -> dict:
    if mode == "correct":
        # Titan Text Embeddings V2: the query text goes in `inputText`.
        # Optional fields like `dimensions` or `normalize` can be added
        # only when you actually need to override the defaults.
        return {
            "inputText": query
            # "dimensions": 1024,
            # "normalize": True,
        }

    if mode == "broken_messages_format":
        # WRONG: this is the Anthropic Messages API shape (role + content
        # blocks). Titan Text Embeddings V2 has no concept of chat turns
        # or roles -- it expects a plain `inputText` field. Sending this
        # will raise a ValidationException.
        return {
            "messages": [
                {"role": "user", "content": [{"type": "text", "text": query}]}
            ]
        }

    raise ValueError(f"Unknown embedding mode: {mode}")


def build_claude_body(mode: str, context: str, question: str) -> dict:
    prompt_text = f"Use the following context to answer the question.\n\nContext:\n{context}\n\nQuestion: {question}"

    if mode == "correct":
        # Claude 3.5 Sonnet on Bedrock, invoked directly, uses the
        # Anthropic Messages API shape: anthropic_version, max_tokens,
        # and a role-based messages array with content blocks.
        return {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 512,
            "messages": [
                {
                    "role": "user",
                    "content": [{"type": "text", "text": prompt_text}],
                }
            ],
        }

    if mode == "broken_legacy_completion":
        # WRONG: this is the OLDER Anthropic text-completion format
        # (Human:/Assistant: delimiters + max_tokens_to_sample). Claude
        # 3.5 Sonnet's Messages API does not accept `prompt` or
        # `max_tokens_to_sample` -- it expects `messages` and `max_tokens`.
        return {
            "prompt": f"\n\nHuman: {prompt_text}\n\nAssistant:",
            "max_tokens_to_sample": 512,
        }

    if mode == "broken_titan_generic_shape":
        # WRONG: this is the Titan TEXT GENERATION request shape
        # (inputText + textGenerationConfig). There is no single
        # "generic" Bedrock Runtime request body -- Claude does not
        # understand textGenerationConfig at all.
        return {
            "inputText": prompt_text,
            "textGenerationConfig": {
                "maxTokenCount": 512,
                "temperature": 0.3,
            },
        }

    raise ValueError(f"Unknown claude mode: {mode}")


# ---------------------------------------------------------------------------
# Invocation + response handling
# ---------------------------------------------------------------------------

def invoke(model_id: str, body: dict) -> dict:
    """Calls Bedrock Runtime InvokeModel and returns a structured result,
    whether it succeeds or fails, so you can inspect both outcomes."""
    try:
        response = bedrock_runtime.invoke_model(
            modelId=model_id,
            contentType="application/json",
            accept="application/json",
            body=json.dumps(body),
        )
        response_body = json.loads(response["body"].read())
        return {
            "outcome": "success",
            "request_body_sent": body,
            "response_body": response_body,
        }
    except ClientError as e:
        return {
            "outcome": "error",
            "request_body_sent": body,
            "error_code": e.response["Error"]["Code"],
            "error_message": e.response["Error"]["Message"],
        }


def summarize_embedding_response(response_body: dict) -> dict:
    embedding = response_body.get("embedding", [])
    return {
        "embedding_length": len(embedding),
        "embedding_preview": embedding[:5],
        "inputTextTokenCount": response_body.get("inputTextTokenCount"),
    }


def summarize_claude_response(response_body: dict) -> dict:
    content_blocks = response_body.get("content", [])
    text = "".join(b.get("text", "") for b in content_blocks if b.get("type") == "text")
    return {
        "generated_text": text,
        "stop_reason": response_body.get("stop_reason"),
        "usage": response_body.get("usage"),
    }


# ---------------------------------------------------------------------------
# Handler
# ---------------------------------------------------------------------------

def lambda_handler(event, context):
    target = event.get("target")
    mode = event.get("mode", "correct")

    if target == "embedding":
        query = event.get("query", "What is a bill of lading exception clause?")
        body = build_embedding_body(mode, query)
        result = invoke(EMBEDDING_MODEL_ID, body)
        if result["outcome"] == "success":
            result["summary"] = summarize_embedding_response(result["response_body"])
        return result

    if target == "claude":
        context_text = event.get("context", "A bill of lading exception clause limits carrier liability for specified causes of loss.")
        question = event.get("question", "What does an exception clause limit?")
        body = build_claude_body(mode, context_text, question)
        result = invoke(CLAUDE_MODEL_ID, body)
        if result["outcome"] == "success":
            result["summary"] = summarize_claude_response(result["response_body"])
        return result

    return {
        "outcome": "error",
        "error_message": "event must include \"target\": \"embedding\" or \"claude\"",
    }

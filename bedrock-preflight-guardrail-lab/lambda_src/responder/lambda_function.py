import os

import boto3

bedrock = boto3.client("bedrock-runtime")
MODEL_ID = os.environ["MODEL_ID"]


def handler(event, context):
    message = event.get("message", "")

    response = bedrock.converse(
        modelId=MODEL_ID,
        messages=[{"role": "user", "content": [{"text": message}]}],
    )

    content = response.get("output", {}).get("message", {}).get("content", [])
    answer = "".join(block.get("text", "") for block in content if "text" in block)

    return {"answer": answer}

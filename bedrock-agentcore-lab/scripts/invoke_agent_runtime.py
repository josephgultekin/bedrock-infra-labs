"""
Invokes the AgentCore Runtime directly (bypassing the Gateway/tools), to
sanity-check that the deployed agent container responds at all.

NOTE (unverified - see README): the boto3 client name ("bedrock-agentcore")
and the invoke_agent_runtime parameter names below are this repo's best
guess at the data-plane SDK shape, not confirmed against live AWS docs from
this sandbox. If this fails with an AttributeError or a parameter-validation
error, check the installed boto3 version's actual operations:

    python3 -c "import boto3; print(boto3.client('bedrock-agentcore').meta.service_model.operation_names)"

Setup:
    export AGENT_RUNTIME_ARN=$(tofu output -raw agent_runtime_arn)

Run:
    python3 invoke_agent_runtime.py "What products do you have?"
"""

import json
import os
import sys
import uuid

import boto3

REGION = boto3.session.Session().region_name or "us-east-1"
agentcore_data_plane = boto3.client("bedrock-agentcore", region_name=REGION)

AGENT_RUNTIME_ARN = os.environ["AGENT_RUNTIME_ARN"]


def main():
    message = " ".join(sys.argv[1:]) or "What products do you have?"
    session_id = str(uuid.uuid4())

    print(f"User: {message}\n")

    response = agentcore_data_plane.invoke_agent_runtime(
        agentRuntimeArn=AGENT_RUNTIME_ARN,
        runtimeSessionId=session_id,
        payload=json.dumps({"prompt": message}).encode("utf-8"),
    )

    body = response["response"].read() if hasattr(response.get("response"), "read") else response.get("response")
    print("Agent:")
    print(body)


if __name__ == "__main__":
    main()

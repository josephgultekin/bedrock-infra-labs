"""
Optional. Talks to the actual agent (not just the Lambda) via InvokeAgent,
using Bedrock's built-in test alias (TSTALIASID), which always runs the
DRAFT version - no alias needs to be created for this.

This is exploratory rather than a deterministic test: the model decides what
to ask the user and when to call the tool, so behavior can vary between
runs. Use test_validator_directly.py as the reliable proof; use this to see
the orchestration in action, including how the agent reacts in conversation
when the validator rejects a call.

Setup:
    export AGENT_ID=$(terraform output -raw agent_id)

Run:
    python3 invoke_agent.py "Book me a pickup appointment"
"""

import os
import sys
import uuid

import boto3

REGION = boto3.session.Session().region_name or "us-east-1"
bedrock_agent_runtime = boto3.client("bedrock-agent-runtime", region_name=REGION)

AGENT_ID = os.environ["AGENT_ID"]
TEST_ALIAS_ID = "TSTALIASID"


def main():
    message = " ".join(sys.argv[1:]) or "I need to book a container pickup appointment."
    session_id = str(uuid.uuid4())

    print(f"User: {message}\n")

    response = bedrock_agent_runtime.invoke_agent(
        agentId=AGENT_ID,
        agentAliasId=TEST_ALIAS_ID,
        sessionId=session_id,
        inputText=message,
    )

    print("Agent:")
    for event in response["completion"]:
        if "chunk" in event:
            text = event["chunk"]["bytes"].decode("utf-8")
            print(text, end="")
        elif "trace" in event:
            # Uncomment to see full orchestration trace, including the raw
            # tool call sent to the validator and its response:
            # print(f"\n[trace] {event['trace']}\n")
            pass
    print()


if __name__ == "__main__":
    main()

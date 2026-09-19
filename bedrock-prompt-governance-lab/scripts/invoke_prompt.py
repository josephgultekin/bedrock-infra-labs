"""
Invokes the managed prompt the correct way: the prompt VERSION's ARN goes in
the modelId field, and the variable value goes in promptVariables. The
application never assembles or embeds the template text itself.

Setup:
    export PROMPT_VERSION_ARN=$(terraform output -raw initial_version_arn)
    # or the ARN printed by publish_approved_prompt.py for a later version
    # (or put these in a .env file - see .env.example)

Run:
    python3 invoke_prompt.py
"""

import os

import boto3
from dotenv import load_dotenv

load_dotenv()

REGION = boto3.session.Session().region_name or "us-east-1"
bedrock_runtime = boto3.client("bedrock-runtime", region_name=REGION)

PROMPT_VERSION_ARN = os.environ["PROMPT_VERSION_ARN"]

SAMPLE_NARRATIVE = (
    "A 54-year-old female patient reported severe nausea and dizziness "
    "approximately 2 hours after taking a single 10mg dose of Product A for "
    "hypertension. Symptoms resolved within 6 hours without treatment. "
    "Patient has a history of migraine. No other concomitant medications "
    "reported. Event assessed as non-serious by the reporting physician."
)


def main():
    response = bedrock_runtime.converse(
        modelId=PROMPT_VERSION_ARN,  # the managed prompt's ARN, not a base model ID
        promptVariables={"narrative_text": {"text": SAMPLE_NARRATIVE}},
    )

    content = response["output"]["message"]["content"]
    summary = "".join(block.get("text", "") for block in content if "text" in block)

    print("Input narrative:")
    print(f"  {SAMPLE_NARRATIVE}\n")
    print("Structured summary (template + variables resolved entirely by Bedrock):")
    print(summary)


if __name__ == "__main__":
    main()

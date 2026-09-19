"""
Models the release step of the team's existing process: change-management
has already approved a prompt edit (represented here by uploading a revised
local file to the versioned S3 source bucket). This script publishes that
approved text into Bedrock Prompt Management's working draft, then creates a
new prompt VERSION - an immutable, point-in-time production snapshot.

This is deliberately NOT the console's "Save as draft" action, which
replaces the draft and discards any other compared variants rather than
preserving history. create_prompt_version is what actually satisfies the
"point-in-time production snapshots" requirement.

Setup:
    export PROMPT_ARN=$(terraform output -raw prompt_arn)
    export SOURCE_BUCKET=$(terraform output -raw source_bucket)
    # (or put these in a .env file - see .env.example)

Run:
    python3 publish_approved_prompt.py source_prompts/adverse_event_summary_v2.txt \
        --change-ticket CM-1002 \
        --description "Added reporter-type field per pharmacovigilance review."
"""

import argparse
import os

import boto3
from dotenv import load_dotenv

load_dotenv()

REGION = boto3.session.Session().region_name or "us-east-1"
bedrock_agent = boto3.client("bedrock-agent", region_name=REGION)
s3 = boto3.client("s3", region_name=REGION)

PROMPT_ARN = os.environ["PROMPT_ARN"]
SOURCE_BUCKET = os.environ["SOURCE_BUCKET"]
SOURCE_KEY = "adverse_event_summary.txt"


def upload_reviewed_source(local_path, change_ticket):
    """Uploads the approved file as a new S3 object version - S3 Versioning
    retains every prior reviewed revision automatically."""
    with open(local_path, "rb") as f:
        s3.put_object(
            Bucket=SOURCE_BUCKET,
            Key=SOURCE_KEY,
            Body=f.read(),
            ContentType="text/plain",
            Metadata={"change-ticket": change_ticket, "approved-by": "pharmacovigilance-governance-team"},
        )
    print(f"Uploaded approved source to s3://{SOURCE_BUCKET}/{SOURCE_KEY} (change ticket {change_ticket})")


def read_approved_text():
    obj = s3.get_object(Bucket=SOURCE_BUCKET, Key=SOURCE_KEY)
    return obj["Body"].read().decode("utf-8")


def update_prompt_draft(approved_text):
    current = bedrock_agent.get_prompt(promptIdentifier=PROMPT_ARN)
    variants = current["variants"]

    for variant in variants:
        if variant["name"] == current.get("defaultVariant"):
            variant["templateConfiguration"]["text"]["text"] = approved_text

    bedrock_agent.update_prompt(
        promptIdentifier=PROMPT_ARN,
        name=current["name"],
        description=current.get("description"),
        defaultVariant=current.get("defaultVariant"),
        variants=variants,
    )
    print("Updated the working draft with the approved text.")


def create_version(description):
    response = bedrock_agent.create_prompt_version(
        promptIdentifier=PROMPT_ARN,
        description=description,
    )
    print(f"Created version {response['version']}: {response['arn']}")
    return response["arn"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("local_path", help="Path to the approved local prompt file")
    parser.add_argument("--change-ticket", required=True)
    parser.add_argument("--description", required=True)
    args = parser.parse_args()

    upload_reviewed_source(args.local_path, args.change_ticket)
    approved_text = read_approved_text()
    update_prompt_draft(approved_text)
    version_arn = create_version(args.description)

    print(f"\nInvoke this exact snapshot with:\n  export PROMPT_VERSION_ARN={version_arn}")


if __name__ == "__main__":
    main()

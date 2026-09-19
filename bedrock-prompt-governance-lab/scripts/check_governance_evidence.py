"""
Ties together all four requirements from the exam scenario into one check:

  1. Reviewed prompt source files retained -> S3 object versions
  2. Point-in-time production snapshots -> Bedrock prompt versions
  3. Audit of Bedrock API usage -> CloudTrail events
  4. Runtime invocation logs, same account/region -> CloudWatch Logs

Run this after publish_approved_prompt.py and invoke_prompt.py, allowing a
few minutes for CloudTrail and invocation logging to catch up.

Setup:
    export PROMPT_ARN=$(terraform output -raw prompt_arn)
    export SOURCE_BUCKET=$(terraform output -raw source_bucket)
    export INVOCATION_LOG_GROUP=$(terraform output -raw invocation_log_group)
    export CLOUDTRAIL_NAME=$(terraform output -raw cloudtrail_name)
    # (or put these in a .env file - see .env.example)

Run:
    python3 check_governance_evidence.py
"""

import os
from datetime import datetime, timedelta, timezone

import boto3
from dotenv import load_dotenv

load_dotenv()

REGION = boto3.session.Session().region_name or "us-east-1"
bedrock_agent = boto3.client("bedrock-agent", region_name=REGION)
s3 = boto3.client("s3", region_name=REGION)
cloudtrail = boto3.client("cloudtrail", region_name=REGION)
logs = boto3.client("logs", region_name=REGION)

PROMPT_ARN = os.environ["PROMPT_ARN"]
SOURCE_BUCKET = os.environ["SOURCE_BUCKET"]
INVOCATION_LOG_GROUP = os.environ["INVOCATION_LOG_GROUP"]
SOURCE_KEY = "adverse_event_summary.txt"


def check_source_versions():
    print(f"\n{'=' * 72}\n1. Reviewed source file versions (S3 Versioning)\n{'=' * 72}")
    response = s3.list_object_versions(Bucket=SOURCE_BUCKET, Prefix=SOURCE_KEY)
    versions = response.get("Versions", [])
    for v in sorted(versions, key=lambda x: x["LastModified"]):
        marker = " (current)" if v["IsLatest"] else ""
        print(f"  VersionId={v['VersionId'][:12]}...  LastModified={v['LastModified']}{marker}")
    if not versions:
        print("  No versions found.")


def check_prompt_versions():
    print(f"\n{'=' * 72}\n2. Bedrock prompt versions (point-in-time production snapshots)\n{'=' * 72}")
    response = bedrock_agent.list_prompts(promptIdentifier=PROMPT_ARN)
    for p in sorted(response.get("promptSummaries", []), key=lambda x: x.get("version", "DRAFT")):
        print(f"  version={p.get('version')}  updatedAt={p.get('updatedAt')}  description={p.get('description')}")
    if not response.get("promptSummaries"):
        print("  No versions found.")


def check_cloudtrail_events():
    print(f"\n{'=' * 72}\n3. CloudTrail Bedrock API audit events (last 60 minutes)\n{'=' * 72}")
    end = datetime.now(timezone.utc)
    start = end - timedelta(minutes=60)
    response = cloudtrail.lookup_events(
        LookupAttributes=[{"AttributeKey": "EventSource", "AttributeValue": "bedrock.amazonaws.com"}],
        StartTime=start,
        EndTime=end,
        MaxResults=10,
    )
    events = response.get("Events", [])
    for e in events:
        print(f"  {e['EventTime']}  {e['EventName']}  by {e.get('Username', 'unknown')}")
    if not events:
        print("  No events found yet - CloudTrail delivery can lag by several minutes.")


def check_invocation_logs():
    print(f"\n{'=' * 72}\n4. Model invocation logs (same account/region CloudWatch Logs)\n{'=' * 72}")
    try:
        streams = logs.describe_log_streams(
            logGroupName=INVOCATION_LOG_GROUP, orderBy="LastEventTime", descending=True, limit=5
        )
    except logs.exceptions.ResourceNotFoundException:
        print(f"  Log group {INVOCATION_LOG_GROUP} not found yet.")
        return

    for stream in streams.get("logStreams", []):
        print(f"  stream={stream['logStreamName']}  lastEvent={stream.get('lastEventTimestamp')}")
    if not streams.get("logStreams"):
        print("  No log streams yet - invoke_prompt.py may not have run, or delivery is still catching up.")


def main():
    check_source_versions()
    check_prompt_versions()
    check_cloudtrail_events()
    check_invocation_logs()
    print(
        f"\n{'=' * 72}\n"
        "All four checks above should show something once "
        "publish_approved_prompt.py and invoke_prompt.py have run and a few "
        "minutes have passed for log/event delivery.\n"
        f"{'=' * 72}"
    )


if __name__ == "__main__":
    main()

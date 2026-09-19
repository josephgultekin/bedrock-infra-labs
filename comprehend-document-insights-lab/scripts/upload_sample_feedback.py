"""
Uploads every file in ../sample_data to s3://<bucket>/incoming/, which
triggers the analyzer Lambda via S3 event notification, then polls for the
corresponding insights/<file>.json object and prints a summary.

Setup:
    export DOCS_BUCKET=$(tofu output -raw docs_bucket)

Run:
    python3 upload_sample_feedback.py
"""

import json
import os
import pathlib
import time

import boto3
from botocore.exceptions import ClientError

REGION = boto3.session.Session().region_name or "us-east-1"
s3 = boto3.client("s3", region_name=REGION)

BUCKET = os.environ["DOCS_BUCKET"]
SAMPLE_DATA_DIR = pathlib.Path(__file__).resolve().parent.parent / "sample_data"
POLL_TIMEOUT_SECONDS = 60
POLL_INTERVAL_SECONDS = 3


def wait_for_insights(filename: str) -> dict | None:
    insights_key = f"insights/{filename}.json"
    deadline = time.time() + POLL_TIMEOUT_SECONDS
    while time.time() < deadline:
        try:
            obj = s3.get_object(Bucket=BUCKET, Key=insights_key)
            return json.loads(obj["Body"].read())
        except ClientError as err:
            if err.response.get("Error", {}).get("Code") != "NoSuchKey":
                raise
        time.sleep(POLL_INTERVAL_SECONDS)
    return None


def print_summary(filename: str, insights: dict) -> None:
    print(f"\n=== {filename} ===")
    print(f"  detected language : {insights['detected_language_code']}")
    print(f"  sentiment         : {insights['sentiment']}")
    print(f"  key phrases       : {', '.join(insights['key_phrases'][:5])}")
    print(f"  entities found    : {len(insights['entities'])}")
    for entity in insights["entities"][:5]:
        print(f"      - {entity['type']}: {entity['text']}")
    if insights["pii_detected"]:
        pii_types = sorted({p["type"] for p in insights["pii_entity_types"]})
        print(f"  PII detected      : yes ({', '.join(pii_types)})")
    else:
        print("  PII detected      : no")


def main():
    files = sorted(SAMPLE_DATA_DIR.glob("*.txt"))
    if not files:
        raise SystemExit(f"No sample files found under {SAMPLE_DATA_DIR}")

    for path in files:
        key = f"incoming/{path.name}"
        print(f"Uploading {path.name} -> s3://{BUCKET}/{key}")
        s3.upload_file(str(path), BUCKET, key)

    for path in files:
        print(f"Waiting for insights on {path.name}...")
        insights = wait_for_insights(path.name)
        if insights is None:
            print(f"  timed out waiting for insights/{path.name}.json - check the Lambda logs")
            continue
        print_summary(path.name, insights)


if __name__ == "__main__":
    main()

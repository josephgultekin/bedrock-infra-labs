"""
Demonstrates the async batch-job path: uploads the sample feedback files to
s3://<bucket>/batch-input/, starts a PII redaction job
(start_pii_entities_detection_job, Mode=ONLY_REDACTION), polls until it
finishes, then downloads the redacted output and prints it next to the
original text so the redaction is visible.

This is the same underlying capability (PII detection) as the real-time
Lambda path, but going through Comprehend's own S3 data-access role instead
of the caller's credentials - the IAM shape worth seeing hands-on.

Setup:
    export DOCS_BUCKET=$(tofu output -raw docs_bucket)
    export DATA_ACCESS_ROLE_ARN=$(tofu output -raw comprehend_data_access_role_arn)

Run:
    python3 run_pii_redaction_job.py
"""

import os
import pathlib
import time
import uuid

import boto3

REGION = boto3.session.Session().region_name or "us-east-1"
comprehend = boto3.client("comprehend", region_name=REGION)
s3 = boto3.client("s3", region_name=REGION)

BUCKET = os.environ["DOCS_BUCKET"]
DATA_ACCESS_ROLE_ARN = os.environ["DATA_ACCESS_ROLE_ARN"]
LANGUAGE_CODE = os.environ.get("DEFAULT_LANGUAGE_CODE", "en")
SAMPLE_DATA_DIR = pathlib.Path(__file__).resolve().parent.parent / "sample_data"

INPUT_PREFIX = "batch-input/"
OUTPUT_PREFIX = "batch-output/"
POLL_INTERVAL_SECONDS = 15


def upload_inputs() -> list[str]:
    files = sorted(SAMPLE_DATA_DIR.glob("*.txt"))
    if not files:
        raise SystemExit(f"No sample files found under {SAMPLE_DATA_DIR}")
    for path in files:
        key = f"{INPUT_PREFIX}{path.name}"
        print(f"Uploading {path.name} -> s3://{BUCKET}/{key}")
        s3.upload_file(str(path), BUCKET, key)
    return [p.name for p in files]


def start_job() -> str:
    job_name = f"pii-redaction-{uuid.uuid4().hex[:8]}"
    response = comprehend.start_pii_entities_detection_job(
        JobName=job_name,
        LanguageCode=LANGUAGE_CODE,
        DataAccessRoleArn=DATA_ACCESS_ROLE_ARN,
        InputDataConfig={
            "S3Uri": f"s3://{BUCKET}/{INPUT_PREFIX}",
            "InputFormat": "ONE_DOC_PER_FILE",
        },
        OutputDataConfig={"S3Uri": f"s3://{BUCKET}/{OUTPUT_PREFIX}"},
        Mode="ONLY_REDACTION",
        RedactionConfig={
            "PiiEntityTypes": ["ALL"],
            "MaskMode": "REPLACE_WITH_PII_ENTITY_TYPE",
        },
    )
    job_id = response["JobId"]
    print(f"Started PII redaction job: {job_id}")
    return job_id


def wait_for_job(job_id: str) -> dict:
    while True:
        status = comprehend.describe_pii_entities_detection_job(JobId=job_id)[
            "PiiEntitiesDetectionJobProperties"
        ]
        state = status["JobStatus"]
        print(f"  status={state}")
        if state in ("COMPLETED", "FAILED", "STOPPED"):
            if state == "FAILED":
                print(f"  failure reason: {status.get('Message')}")
            return status
        time.sleep(POLL_INTERVAL_SECONDS)


def print_redacted_output(job_status: dict, original_filenames: list[str]) -> None:
    output_s3_uri = job_status["OutputDataConfig"]["S3Uri"]
    output_prefix = output_s3_uri.removeprefix(f"s3://{BUCKET}/")

    listing = s3.list_objects_v2(Bucket=BUCKET, Prefix=output_prefix)
    output_keys = {obj["Key"] for obj in listing.get("Contents", [])}

    for filename in original_filenames:
        matches = [k for k in output_keys if k.endswith(filename)]
        if not matches:
            print(f"\n=== {filename}: no redacted output found under {output_prefix} ===")
            continue
        redacted = s3.get_object(Bucket=BUCKET, Key=matches[0])["Body"].read().decode("utf-8")
        original = (SAMPLE_DATA_DIR / filename).read_text()
        print(f"\n=== {filename} ===")
        print(f"  original : {original.strip()}")
        print(f"  redacted : {redacted.strip()}")


def main():
    filenames = upload_inputs()
    job_id = start_job()
    job_status = wait_for_job(job_id)
    if job_status["JobStatus"] != "COMPLETED":
        raise SystemExit(f"Job did not complete: {job_status['JobStatus']}")
    print_redacted_output(job_status, filenames)


if __name__ == "__main__":
    main()

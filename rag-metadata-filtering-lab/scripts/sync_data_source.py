"""
Starts an ingestion job for the S3 data source and waits for it to finish.
Terraform provisions the Knowledge Base and data source, but syncing content
(reading the bulletins + their .metadata.json sidecars, embedding, and
writing vectors) is a separate, explicit action - just like in the console.

Setup:
    export KNOWLEDGE_BASE_ID=$(terraform output -raw knowledge_base_id)
    export DATA_SOURCE_ID=$(terraform output -raw data_source_id)

Run:
    python3 sync_data_source.py
"""

import os
import time

import boto3

REGION = boto3.session.Session().region_name or "us-east-1"
bedrock_agent = boto3.client("bedrock-agent", region_name=REGION)

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
DATA_SOURCE_ID = os.environ["DATA_SOURCE_ID"]


def main():
    print("Starting ingestion job...")
    job = bedrock_agent.start_ingestion_job(
        knowledgeBaseId=KNOWLEDGE_BASE_ID,
        dataSourceId=DATA_SOURCE_ID,
    )
    job_id = job["ingestionJob"]["ingestionJobId"]
    print(f"Ingestion job started: {job_id}")

    while True:
        status = bedrock_agent.get_ingestion_job(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            dataSourceId=DATA_SOURCE_ID,
            ingestionJobId=job_id,
        )["ingestionJob"]
        state = status["status"]
        print(f"  status={state}")
        if state in ("COMPLETE", "FAILED"):
            stats = status.get("statistics", {})
            print(f"  documents scanned: {stats.get('numberOfDocumentsScanned')}")
            print(f"  new documents indexed: {stats.get('numberOfNewDocumentsIndexed')}")
            print(f"  documents failed: {stats.get('numberOfDocumentsFailed')}")
            if state == "FAILED":
                for reason in status.get("failureReasons", []):
                    print(f"  failure reason: {reason}")
            break
        time.sleep(10)


if __name__ == "__main__":
    main()

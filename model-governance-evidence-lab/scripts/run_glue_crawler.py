"""
Runs the Glue crawler that catalogs the source vessel-incident dataset, then
reads back the inferred schema. This is the data-provenance half of the
evidence framework - deliberately separate from Model Cards, which cover
model governance rather than dataset lineage.

Setup:
    export GLUE_CRAWLER_NAME=$(terraform output -raw glue_crawler_name)
    export GLUE_DATABASE_NAME=$(terraform output -raw glue_database_name)

Run:
    python3 run_glue_crawler.py
"""

import os
import time

import boto3

REGION = boto3.session.Session().region_name or "us-east-1"
glue = boto3.client("glue", region_name=REGION)

CRAWLER_NAME = os.environ["GLUE_CRAWLER_NAME"]
DATABASE_NAME = os.environ["GLUE_DATABASE_NAME"]


def main():
    print(f"Starting crawler: {CRAWLER_NAME}")
    glue.start_crawler(Name=CRAWLER_NAME)

    while True:
        state = glue.get_crawler(Name=CRAWLER_NAME)["Crawler"]["State"]
        print(f"  state={state}")
        if state == "READY":
            break
        time.sleep(10)

    tables = glue.get_tables(DatabaseName=DATABASE_NAME).get("TableList", [])
    if not tables:
        print("No tables found - check the crawler's S3 target and IAM permissions.")
        return

    for t in tables:
        print(f"\nTable: {t['Name']}")
        print(f"  Location: {t['StorageDescriptor']['Location']}")
        print("  Inferred columns:")
        for col in t["StorageDescriptor"]["Columns"]:
            print(f"    - {col['Name']} ({col['Type']})")
        print(f"  Created: {t.get('CreateTime')}  Updated: {t.get('UpdateTime')}")


if __name__ == "__main__":
    main()

"""
Demonstrates retrieval-time metadata filtering against the S3-Vectors-backed
knowledge base: authorized product families, an authoring-team filter, and an
effective-timestamp cutoff - combined into ONE top-level RetrievalFilter, since
RetrievalFilter is a union type and cannot hold multiple independent top-level
operators.

Because S3 Vectors currently supports only STRING/NUMBER/BOOLEAN metadata
(not STRING_LIST - see README), "authorized product families" is expressed
here as an `in` filter against a scalar STRING attribute on each document,
rather than storing a list value on the document itself.

Setup:
    export KNOWLEDGE_BASE_ID=$(terraform output -raw knowledge_base_id)

Run (after sync_data_source.py has completed):
    python3 query_with_filters.py
"""

import json
import os

import boto3

REGION = boto3.session.Session().region_name or "us-east-1"
bedrock_agent_runtime = boto3.client("bedrock-agent-runtime", region_name=REGION)

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
QUERY_TEXT = "What maintenance issue should I check on my equipment?"


def run_query(label, retrieval_filter=None):
    print(f"\n{'=' * 72}\n{label}\n{'=' * 72}")

    vector_search_config = {"numberOfResults": 10}
    if retrieval_filter is not None:
        vector_search_config["filter"] = retrieval_filter
        print(f"Filter: {json.dumps(retrieval_filter, indent=2)}")

    response = bedrock_agent_runtime.retrieve(
        knowledgeBaseId=KNOWLEDGE_BASE_ID,
        retrievalQuery={"text": QUERY_TEXT},
        retrievalConfiguration={"vectorSearchConfiguration": vector_search_config},
    )

    results = response.get("retrievalResults", [])
    if not results:
        print("(no results)")
        return

    for r in results:
        uri = r.get("location", {}).get("s3Location", {}).get("uri", "unknown")
        metadata = r.get("metadata", {})
        pf = metadata.get("product_family")
        team = metadata.get("authoring_team")
        eff = metadata.get("effective_date")
        print(f"  {uri}  [product_family={pf}, authoring_team={team}, effective_date={eff}]")


def main():
    # 1. Baseline - no filter, everything is a candidate.
    run_query("1. No filter (baseline - all four bulletins are candidates)")

    # 2. Authorized product families only. `in` works against a scalar STRING
    #    attribute per document - the list lives in the query, not the document.
    run_query(
        "2. Authorized product families = Tractors or Combines (Sprayers excluded)",
        {"in": {"key": "product_family", "value": ["Tractors", "Combines"]}},
    )

    # 3. Authoring team filter alone.
    run_query(
        "3. Authoring team = Powertrain",
        {"equals": {"key": "authoring_team", "value": "Powertrain"}},
    )

    # 4. Effective-timestamp cutoff. Requires NUMBER metadata - this is exactly
    #    why effective_date is stored as YYYYMMDD NUMBER, not a date string.
    run_query(
        "4. Effective date >= 2026-01-01 (the 2025 brake bulletin is excluded)",
        {"greaterThanOrEquals": {"key": "effective_date", "value": 20260101}},
    )

    # 5. All three combined in one top-level `andAll` - the only valid way to
    #    combine conditions, since RetrievalFilter is a union type and a
    #    request cannot specify several independent top-level members.
    run_query(
        "5. Combined: authorized families AND team=Powertrain AND effective_date >= 2026-01-01",
        {
            "andAll": [
                {"in": {"key": "product_family", "value": ["Tractors", "Combines"]}},
                {"equals": {"key": "authoring_team", "value": "Powertrain"}},
                {"greaterThanOrEquals": {"key": "effective_date", "value": 20260101}},
            ]
        },
    )
    # Expected: only tractor-hydraulic-2026 survives all three conditions -
    # combines-sensor-2026 fails the team filter, tractor-brake-2025 fails
    # both the date filter and (moot) predates it, sprayer-nozzle-2026 fails
    # the product-family filter.


if __name__ == "__main__":
    main()

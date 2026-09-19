"""
Simulates the CI/CD governance pipeline step from the exam scenario:

  1. Read metadata from a registered SageMaker Model Package, the way an
     automated deployment pipeline would.
  2. Validate/enrich that metadata before anything is approved - AWS
     explicitly warns that content imported from the Model Registry into a
     Model Card "can be missing or inaccurate" and must be reviewed.
  3. Approve the model package itself at the registry level (a separate,
     complementary governance control from the Model Card).
  4. Create a schema-compliant SageMaker Model Card via the API, in Draft.
  5. Add real evaluation results, move it to PendingReview.
  6. Approve it, only now that validation + evaluation are both done.
  7. Make a follow-up content edit to prove version history is preserved.
  8. List all versions to show that history survived the edit.
  9. Emit a sample runtime decision event to CloudWatch Logs, tied to a
     specific model card version - the operational-audit half of the
     evidence framework, kept separate from the governance artifact itself.

Setup:
    pip install -r requirements.txt
    export MODEL_PACKAGE_ARN=$(terraform output -raw model_package_arn)
    export RUNTIME_LOG_GROUP=$(terraform output -raw runtime_events_log_group)

Run:
    python3 governance_pipeline.py
"""

import json
import os
import time

import boto3

REGION = boto3.session.Session().region_name or "us-east-1"
sm = boto3.client("sagemaker", region_name=REGION)
logs = boto3.client("logs", region_name=REGION)

MODEL_CARD_NAME = "vessel-maintenance-summarizer"
MODEL_PACKAGE_ARN = os.environ["MODEL_PACKAGE_ARN"]
RUNTIME_LOG_GROUP = os.environ["RUNTIME_LOG_GROUP"]


def step(title):
    print(f"\n{'=' * 72}\n{title}\n{'=' * 72}")


def main():
    # ---- 1. Read from the registry, as an automated pipeline would ----
    step("1. Reading model package metadata from the SageMaker Model Registry")
    package = sm.describe_model_package(ModelPackageName=MODEL_PACKAGE_ARN)
    print(f"Model package ARN: {package['ModelPackageArn']}")
    print(f"Approval status (as registered): {package['ModelPackageStatus']}")
    # The registry entry carries deployment metadata (containers, approval
    # status) but no governance fields at all - no risk rating, no business
    # context. That gap is exactly what "imported information can be missing
    # or inaccurate" means in practice: this metadata simply isn't there and
    # must be supplied and reviewed by a human/pipeline step, not assumed.
    print("Imported risk_rating from registry: None (not present - must be supplied by governance review)")

    # ---- 2. Validate / enrich before anything is approved ----
    step("2. Validating and enriching governance content before approval")
    validated_risk_rating = "Medium"
    validated_business_problem = (
        "Summarize vessel maintenance incident reports for fleet engineers "
        "to speed up triage and reduce time-to-repair."
    )
    print(f"Set risk_rating -> {validated_risk_rating}")
    print(f"Set business_problem -> {validated_business_problem}")

    # ---- 3. Approve at the registry level, now that it's been validated ----
    step("3. Approving the model package in the registry")
    sm.update_model_package(
        ModelPackageArn=MODEL_PACKAGE_ARN,
        ModelApprovalStatus="Approved",
        ApprovalDescription="Validated by AI governance team prior to model card approval.",
    )
    print("Model package approval status -> Approved.")

    # ---- 4. Create the schema-compliant model card, in Draft ----
    step("4. Creating the SageMaker Model Card (Draft)")
    content = {
        "model_overview": {
            "model_description": "Generative summarization assistant for vessel maintenance incident reports.",
            "model_owner": "Maritime AI Governance Team",
        },
        "intended_uses": {
            "purpose_of_model": "Summarize vessel maintenance incidents for engineering review.",
            "intended_uses": "Internal engineering triage support only. Not for autonomous maintenance decisions.",
            "factors_affecting_model_efficiency": "Summary quality depends on completeness of source incident logs.",
            "risk_rating": validated_risk_rating,
            "explanations_for_risk_rating": (
                "Model output informs but does not replace human maintenance decisions; "
                "errors are reviewable and reversible before any action is taken."
            ),
        },
        "business_details": {
            "business_problem": validated_business_problem,
            "business_stakeholders": "Fleet engineering, safety/compliance, AI governance",
            "line_of_business": "Maritime operations",
        },
        "evaluation_details": [
            {
                "name": "summarization-accuracy-eval-v1",
                "evaluation_observation": (
                    "Initial evaluation pending. Placeholder created in Draft status; "
                    "populated with metric results before PendingReview."
                ),
            }
        ],
        "additional_information": {
            "ethical_considerations": "Output must not be used as the sole basis for safety-critical repair decisions.",
            "caveats_and_recommendations": "Recommend human sign-off on all generated summaries before action.",
        },
        "model_package_details": {
            "model_package_arn": package["ModelPackageArn"],
            "model_package_description": "Registered vessel-maintenance summarization model version.",
        },
    }

    sm.create_model_card(
        ModelCardName=MODEL_CARD_NAME,
        Content=json.dumps(content),
        ModelCardStatus="Draft",
    )
    print(f"Created model card '{MODEL_CARD_NAME}' in Draft status.")

    # ---- 5. Add real evaluation results, move to PendingReview ----
    step("5. Adding evaluation results, moving to PendingReview")
    content["evaluation_details"] = [
        {
            "name": "summarization-accuracy-eval-v1",
            "evaluation_observation": (
                "Ran against 50 held-out incident reports. Factual consistency "
                "score 0.91, hallucination rate 3%. Reviewed by AI governance team."
            ),
            "metric_groups": [
                {
                    "name": "quality",
                    "metric_data": [
                        {"name": "factual_consistency", "type": "number", "value": 0.91},
                        {"name": "hallucination_rate", "type": "number", "value": 0.03},
                    ],
                }
            ],
        }
    ]
    sm.update_model_card(
        ModelCardName=MODEL_CARD_NAME,
        Content=json.dumps(content),
        ModelCardStatus="PendingReview",
    )
    print("Content updated with evaluation results; status -> PendingReview.")

    # ---- 6. Approve, now that validation + evaluation are both complete ----
    step("6. Approving the model card")
    sm.update_model_card(ModelCardName=MODEL_CARD_NAME, ModelCardStatus="Approved")
    print("Model card status -> Approved.")

    # ---- 7. A later content revision, to show version history is preserved ----
    step("7. Making a follow-up content revision")
    content["additional_information"]["caveats_and_recommendations"] += (
        " Update: added guidance excluding engine-room fire incidents from "
        "automated summarization pending further evaluation."
    )
    sm.update_model_card(
        ModelCardName=MODEL_CARD_NAME,
        Content=json.dumps(content),
        ModelCardStatus="Approved",
    )
    print("Content revised. SageMaker retains this as a new version, not an overwrite.")

    # ---- 8. List version history ----
    step("8. Listing model card version history")
    versions = sm.list_model_card_versions(ModelCardName=MODEL_CARD_NAME)
    try:
        version_list = versions["ModelCardVersionSummaryList"]
        for v in sorted(version_list, key=lambda x: x["ModelCardVersion"]):
            when = v.get("LastModifiedTime", v.get("CreationTime"))
            print(f"  v{v['ModelCardVersion']}: status={v['ModelCardStatus']}, last_modified={when}")
        latest_version = max(v["ModelCardVersion"] for v in version_list)
    except KeyError:
        print("(Response field name differs from expected - printing raw response.)")
        print(json.dumps(versions, default=str, indent=2))
        latest_version = "unknown"

    # ---- 9. Emit a sample runtime decision event ----
    step("9. Logging a sample runtime decision event")
    log_stream = f"pipeline-run-{int(time.time())}"
    logs.create_log_stream(logGroupName=RUNTIME_LOG_GROUP, logStreamName=log_stream)
    event = {
        "incident_id": "INC-1002",
        "vessel_id": "VSL-118",
        "model_card_name": MODEL_CARD_NAME,
        "model_card_version": latest_version,
        "decision": "SUMMARY_GENERATED_PENDING_ENGINEER_REVIEW",
        "timestamp": int(time.time()),
    }
    logs.put_log_events(
        logGroupName=RUNTIME_LOG_GROUP,
        logStreamName=log_stream,
        logEvents=[{"timestamp": int(time.time() * 1000), "message": json.dumps(event)}],
    )
    print(f"Logged runtime decision event to {RUNTIME_LOG_GROUP} / {log_stream}")
    print(json.dumps(event, indent=2))

    print(
        "\nDone. View the card in the console: "
        f"SageMaker -> Governance -> Model cards -> {MODEL_CARD_NAME}"
    )


if __name__ == "__main__":
    main()

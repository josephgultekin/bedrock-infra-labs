"""
Queries the AWS/Bedrock CloudWatch metrics after compare_invocation_modes.py
has run, to confirm server-side what the client already observed - and to
make a real limitation of these metrics concrete: there is no Operation
dimension on the base runtime metrics, only ModelId. That means:

  - Invocations' sample count reflects streaming AND non-streaming calls
    combined for this model.
  - TimeToFirstToken's sample count reflects ONLY the streaming calls,
    because it is never emitted for non-streaming Converse/InvokeModel calls.

So TimeToFirstToken's mere presence (and its sample count) is itself the
signal that separates "did any streaming calls happen" from the rest -
there's no way to filter InvocationLatency down to just the streaming subset
using these built-in dimensions alone.

Setup:
    export MODEL_ID=$(terraform output -raw model_id)

Run (wait a few minutes after compare_invocation_modes.py for metrics to land):
    python3 check_cloudwatch_metrics.py
"""

import os
from datetime import datetime, timedelta, timezone

import boto3

REGION = boto3.session.Session().region_name or "us-east-1"
cloudwatch = boto3.client("cloudwatch", region_name=REGION)

MODEL_ID = os.environ.get("MODEL_ID", "anthropic.claude-3-5-haiku-20241022-v1:0")
LOOKBACK_MINUTES = 30


def metric_query(query_id, metric_name, stat):
    return {
        "Id": query_id,
        "MetricStat": {
            "Metric": {
                "Namespace": "AWS/Bedrock",
                "MetricName": metric_name,
                "Dimensions": [{"Name": "ModelId", "Value": MODEL_ID}],
            },
            "Period": LOOKBACK_MINUTES * 60,
            "Stat": stat,
        },
        "ReturnData": True,
    }


def main():
    end = datetime.now(timezone.utc)
    start = end - timedelta(minutes=LOOKBACK_MINUTES)

    queries = [
        metric_query("invocations_count", "Invocations", "SampleCount"),
        metric_query("invocation_latency_count", "InvocationLatency", "SampleCount"),
        metric_query("ttft_count", "TimeToFirstToken", "SampleCount"),
        metric_query("invocation_latency_p50", "InvocationLatency", "p50"),
        metric_query("invocation_latency_p90", "InvocationLatency", "p90"),
        metric_query("ttft_p50", "TimeToFirstToken", "p50"),
        metric_query("ttft_p90", "TimeToFirstToken", "p90"),
    ]

    response = cloudwatch.get_metric_data(
        MetricDataQueries=queries, StartTime=start, EndTime=end
    )
    values = {
        r["Id"]: (r["Values"][0] if r["Values"] else None)
        for r in response["MetricDataResults"]
    }

    print(f"AWS/Bedrock metrics for ModelId={MODEL_ID}, last {LOOKBACK_MINUTES} minutes:\n")

    print("Sample counts:")
    print(f"  Invocations:        {values['invocations_count']}  (streaming + non-streaming combined)")
    print(f"  InvocationLatency:  {values['invocation_latency_count']}  (streaming + non-streaming combined)")
    print(f"  TimeToFirstToken:   {values['ttft_count']}  (streaming calls only)")

    print("\nLatency (milliseconds):")
    print(f"  InvocationLatency  p50 = {values['invocation_latency_p50']}, p90 = {values['invocation_latency_p90']}")
    print(f"  TimeToFirstToken   p50 = {values['ttft_p50']}, p90 = {values['ttft_p90']}")

    if values["ttft_count"] is None:
        print("\nNo TimeToFirstToken datapoints yet - metrics can take a few minutes to appear, or no streaming calls have run.")
    elif values["invocations_count"] and values["ttft_count"]:
        print(
            f"\nExpected pattern: TimeToFirstToken's sample count "
            f"({values['ttft_count']:.0f}) should be smaller than Invocations' "
            f"({values['invocations_count']:.0f}), since only the streaming "
            "runs contribute to it."
        )


if __name__ == "__main__":
    main()

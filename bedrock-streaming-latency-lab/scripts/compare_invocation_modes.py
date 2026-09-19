"""
Runs the exam scenario's actual prompt shape - multi-paragraph rebooking
guidance from an operational event - through both the current non-streaming
Converse API and the proposed streaming ConverseStream API, against the same
model, measuring what an operator would actually perceive in each case.

Setup:
    export MODEL_ID=$(terraform output -raw model_id)

Run:
    python3 compare_invocation_modes.py
"""

import os
import time

import boto3

REGION = boto3.session.Session().region_name or "us-east-1"
bedrock_runtime = boto3.client("bedrock-runtime", region_name=REGION)

MODEL_ID = os.environ.get("MODEL_ID", "anthropic.claude-3-5-haiku-20241022-v1:0")

PROMPT = (
    "A connecting passenger's flight was cancelled due to weather at a major "
    "hub airport. Write detailed, multi-paragraph rebooking guidance for a "
    "gate agent to read to the passenger, covering: alternative routing "
    "options for the next 24 hours, hotel and meal voucher eligibility rules, "
    "and clear next steps the passenger should take right now."
)

RUNS = 3


def run_nonstreaming():
    print(f"\n{'=' * 72}\nNon-streaming Converse (current approach)\n{'=' * 72}")
    for i in range(1, RUNS + 1):
        start = time.perf_counter()
        response = bedrock_runtime.converse(
            modelId=MODEL_ID,
            messages=[{"role": "user", "content": [{"text": PROMPT}]}],
        )
        end = time.perf_counter()
        text = "".join(
            block.get("text", "")
            for block in response["output"]["message"]["content"]
            if "text" in block
        )
        blank_screen_ms = (end - start) * 1000
        print(
            f"  run {i}: blank screen for {blank_screen_ms:8.0f} ms "
            f"before ANY content renders ({len(text)} chars total)"
        )


def run_streaming():
    print(f"\n{'=' * 72}\nStreaming ConverseStream (proposed approach)\n{'=' * 72}")
    for i in range(1, RUNS + 1):
        start = time.perf_counter()
        response = bedrock_runtime.converse_stream(
            modelId=MODEL_ID,
            messages=[{"role": "user", "content": [{"text": PROMPT}]}],
        )

        first_chunk_time = None
        total_chars = 0
        for event in response["stream"]:
            if "contentBlockDelta" in event:
                if first_chunk_time is None:
                    first_chunk_time = time.perf_counter()
                delta = event["contentBlockDelta"].get("delta", {})
                total_chars += len(delta.get("text", ""))
        end = time.perf_counter()

        ttft_ms = (first_chunk_time - start) * 1000 if first_chunk_time else float("nan")
        total_ms = (end - start) * 1000
        print(
            f"  run {i}: first content visible after {ttft_ms:8.0f} ms, "
            f"full response after {total_ms:8.0f} ms ({total_chars} chars total)"
        )


def main():
    run_nonstreaming()
    run_streaming()
    print(
        f"\n{'=' * 72}\n"
        "In the non-streaming runs, the operator sees a blank screen for the "
        "entire duration shown. In the streaming runs, the first words appear "
        "at 'first content visible' - much sooner - even though the full "
        "response takes roughly as long overall. That gap is exactly what "
        "TimeToFirstToken measures server-side.\n\n"
        "Run check_cloudwatch_metrics.py in a few minutes to see it show up "
        "in CloudWatch.\n"
        f"{'=' * 72}"
    )


if __name__ == "__main__":
    main()

# Streaming latency instrumentation lab (airline rebooking guidance)

Demonstrates the exam's correct answer directly: switch a Converse call to
`ConverseStream`, render tokens as they arrive, and instrument both
`TimeToFirstToken` (initial visible delay) and `InvocationLatency` (total
generation duration) in the `AWS/Bedrock` CloudWatch namespace.

```
scripts/compare_invocation_modes.py
    runs the same multi-paragraph rebooking-guidance prompt through:
      - Converse           (current approach - blank screen until done)
      - ConverseStream     (proposed approach - first words arrive fast)
    and prints client-observed timings for both.

scripts/check_cloudwatch_metrics.py
    queries CloudWatch a few minutes later to confirm server-side what the
    client already showed, and makes a real metric limitation concrete
    (see below).

Terraform provisions:
    - An IAM policy for running the scripts (not auto-attached)
    - A CloudWatch dashboard graphing TimeToFirstToken and InvocationLatency
    - Two alarms - one per axis the exam question asks you to instrument
```

## A real limitation worth understanding, not just knowing the metric names

I checked AWS's current runtime-metrics documentation before building this,
and there's a detail worth being explicit about: **the only dimension on
these base runtime metrics is `ModelId`** - there is no `Operation`
dimension separating `Converse` from `ConverseStream` calls. That means:

- `Invocations` and `InvocationLatency` reflect **all** calls to a model -
  streaming and non-streaming combined. You cannot filter `InvocationLatency`
  down to just your streaming traffic using the built-in dimensions alone.
- `TimeToFirstToken` is different: it's *only ever emitted* for
  `ConverseStream`/`InvokeModelWithResponseStream` calls. So its mere
  presence - and its sample count - is itself the signal that isolates
  streaming behavior, even though the metric namespace doesn't give you an
  explicit filter for it.

`check_cloudwatch_metrics.py` makes this concrete: it prints the sample
counts for all three metrics side by side, and you should see
`TimeToFirstToken`'s count come out smaller than `Invocations`' count,
reflecting only the streaming runs. This doesn't change which answer is
correct on the exam - it's still the right pattern - but it's exactly the
kind of production nuance that's easy to miss if you only memorize the
metric names.

## Prerequisites

1. Terraform >= 1.6 and AWS credentials able to create IAM, CloudWatch
   dashboard, SNS, and CloudWatch alarm resources.
2. **Bedrock model access enabled** for `anthropic.claude-3-5-haiku-20241022-v1:0`
   in your target region (Bedrock console -> Model access).
3. Python 3.9+ and `pip install -r scripts/requirements.txt`.

As with the other labs: written carefully, not validated against a live
account or the Terraform Registry in this sandbox. This lab's Terraform is
comparatively simple (no Lambda, no agent) - IAM policies, a dashboard, and
two alarms - so the main thing worth double-checking is the CloudWatch
dashboard widget JSON shape if the console renders it unexpectedly.

## Run it

```bash
terraform init
terraform plan
terraform apply
```

```bash
cd scripts
pip install -r requirements.txt

export MODEL_ID=$(terraform output -chdir=.. -raw model_id)
```

### 1. See the perceived-latency difference directly

```bash
python3 compare_invocation_modes.py
```

Watch the non-streaming runs report one blank-screen number, and the
streaming runs report a much smaller "first content visible" number
alongside a similar total time - that gap is the entire value proposition of
streaming for this scenario.

### 2. Confirm it server-side in CloudWatch

Wait a few minutes for metrics to land, then:

```bash
python3 check_cloudwatch_metrics.py
```

Or open the dashboard directly:

```bash
terraform output -chdir=.. -raw dashboard_url
```

## Alarms

Two alarms map directly onto the exam requirement to instrument both the
initial delay and the total duration separately:

- `*-ttft-p90-high` - fires if p90 `TimeToFirstToken` exceeds
  `var.ttft_alarm_threshold_ms` (default 3000 ms).
- `*-invocation-latency-p90-high` - fires if p90 `InvocationLatency` exceeds
  `var.total_latency_alarm_threshold_ms` (default 15000 ms).

Both are `notBreaching` on missing data (so they don't false-alarm during
periods with no traffic) and publish to an SNS topic. Set `alert_email` in
a `terraform.tfvars` file if you want a real subscription; otherwise the
topic exists with no subscribers and nothing will ever notify you, which is
fine for just exploring the alarm configuration.

## Cost notes

Nothing here has a standing cost. IAM, the CloudWatch dashboard, alarms, and
the SNS topic are all free or effectively free at this scale. The only real
per-call cost is the Bedrock model invocations from `compare_invocation_modes.py`
- six short calls total (three non-streaming, three streaming) against
Claude Haiku, fractions of a cent.

## Clean up

```bash
terraform destroy
```

No standing charges exist in this stack, but there's no reason to leave it
up once you're done testing.

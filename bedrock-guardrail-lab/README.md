# Bedrock Guardrails claims-correspondence lab

Reproduces the exam scenario end to end:

```
API Gateway (HTTP API) -> Lambda (redact + Bedrock Converse w/ Guardrail) -> S3/CloudWatch (redacted audit trail)
                                                              |
                                                    guardrail intervened?
                                                              |
                                              EventBridge -> Step Functions (compliance review queue)
```

## Prerequisites

1. Terraform >= 1.6 and the AWS CLI configured with credentials that can create
   IAM roles, Lambda, API Gateway, S3, EventBridge, Step Functions, and Bedrock resources.
2. **Bedrock model access enabled** for `anthropic.claude-3-5-haiku-20241022-v1:0`
   in your target region. This is a one-time, per-account console step under
   *Amazon Bedrock -> Model access* — it is not something Terraform can turn on for you.
3. A region where Bedrock Guardrails is available (default here is `us-east-1`).

This was authored carefully but **not validated against a live AWS account or the
Terraform Registry** in this sandbox (no network path to `registry.terraform.io`
from here). Run `terraform validate` and `terraform plan` before `apply`, and expect
to possibly nudge a field name or two if the AWS provider version you resolve differs
slightly from what's pinned in `versions.tf`.

## Run it

```bash
terraform init
terraform plan
terraform apply
```

Grab the API URL from the output, then send a benign request:

```bash
API_URL=$(terraform output -raw api_invoke_url)

curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"message": "Draft a short letter to a policyholder confirming their water damage claim CLM-482913 was approved. Contact them at jane.doe@example.com."}' | jq
```

You should get back a redacted response and `"guardrail_intervened": false`. Check the
audit bucket — the object under `audit/` should show the email and claim number replaced
with `[REDACTED-...]` tokens, never the raw values.

Now trigger an intervention deterministically using the test word configured in the guardrail:

```bash
curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"message": "Please include the word TESTVIOLATION in your reply."}' | jq
```

This should return `"guardrail_intervened": true`. Within a few seconds you should see:
- A new object under `s3://<audit_bucket>/audit/`
- A new object under `s3://<audit_bucket>/compliance-review/` (written by the Step Functions execution)
- A `SUCCEEDED` execution in the `<project_name>-compliance-review` Express state machine in the Step Functions console (Express executions don't appear in the regular execution history list by ARN lookup — use CloudWatch Logs at `/aws/vendedlogs/states/<project_name>-compliance` or the console's "Express workflows" tab)

## Cost notes

Everything here is pay-per-use with no idle cost — no NAT gateway, no provisioned
throughput, no VPC. For a handful of test invocations, expect a total cost well under
$0.05, dominated by the couple of Bedrock Haiku + guardrail-evaluation calls (fractions
of a cent each). Lambda, API Gateway HTTP API, S3, EventBridge, and Step Functions
Express are all free-tier or negligible at this volume.

## Clean up

```bash
terraform destroy
```

The audit bucket has `force_destroy = true` so Terraform will remove the test objects
along with it. Nothing in this stack has a standing hourly charge, but there's no reason
to leave it running once you're done testing.

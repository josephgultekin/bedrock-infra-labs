# Amazon Comprehend document-insights lab

Two ways of using Amazon Comprehend against the same sample customer-feedback
documents, since they have genuinely different shapes worth seeing hands-on:

```
S3 bucket (incoming/) --S3 event--> Lambda (analyzer)
                                        |
                          DetectDominantLanguage, then with that
                          language code: DetectSentiment,
                          DetectKeyPhrases, DetectEntities,
                          DetectPiiEntities (offsets/types only,
                          never raw PII text)
                                        |
                                        v
                          S3 bucket (insights/<file>.json)

scripts/run_pii_redaction_job.py:
S3 bucket (batch-input/) --> StartPiiEntitiesDetectionJob
   (Mode=ONLY_REDACTION, DataAccessRoleArn = dedicated
   Comprehend service role, not the Lambda's role)
                                        |
                                        v
S3 bucket (batch-output/) -- redacted copies of the input docs
```

The real-time path uses the caller's own IAM permissions for synchronous,
per-document inference calls. The batch path is asynchronous and has
Comprehend itself assume a separate `DataAccessRoleArn` to read/write S3 -
a distinct IAM model that's easy to get wrong the first time you hit it.

## Prerequisites

1. OpenTofu >= 1.6 (or Terraform >= 1.6 - the config is plain HCL and works
   with either) and the AWS CLI configured with credentials that can create
   IAM roles, Lambda, and S3 resources.
2. Python 3.9+ and `pip install -r scripts/requirements.txt`.
3. A region where Amazon Comprehend is available (default here is
   `us-east-1`). Unlike Bedrock, Comprehend has **no** one-time "model
   access" console step to enable - the Detect* APIs and batch jobs work
   as soon as your IAM permissions allow them.

This was authored carefully and validated with `tofu validate` and a real
`tofu plan` against a live account, but not yet with a full `apply` - double
check the `start_pii_entities_detection_job` request shape and the IAM
actions in `iam.tf` against current boto3/AWS docs if `apply` or the scripts
throw an error.

## What gets built

One S3 bucket with four key prefixes: `incoming/` (uploads trigger the
Lambda), `insights/` (Lambda output), `batch-input/` and `batch-output/`
(used only by the redaction-job script). `sample_data/` has four short
customer-feedback files chosen to exercise every API meaningfully:

| File | What it demonstrates |
|---|---|
| `positive_feedback.txt` | Clean positive sentiment, no PII |
| `negative_feedback_with_pii.txt` | Negative sentiment + a real name/email/phone to detect and redact |
| `mixed_feedback.txt` | Person + organization entities, key phrases |
| `spanish_feedback.txt` | Non-English text, so `DetectDominantLanguage` actually does something observable |

## Run it

```bash
tofu init
tofu plan
tofu apply
```

### 1. Real-time detection (S3-triggered Lambda)

```bash
cd scripts
pip install -r requirements.txt

export DOCS_BUCKET=$(tofu output -chdir=.. -raw docs_bucket)
python3 upload_sample_feedback.py
```

This uploads each sample file to `incoming/`, waits for the Lambda to write
`insights/<file>.json`, and prints a summary: detected language, sentiment,
top key phrases, entities found, and which PII types (not values) were
detected. `negative_feedback_with_pii.txt` should come back
`sentiment=NEGATIVE` with `PII detected: yes (EMAIL, NAME, PHONE)` (exact
type set depends on Comprehend's current PII taxonomy).

### 2. Async batch job with automatic redaction

```bash
export DATA_ACCESS_ROLE_ARN=$(tofu output -chdir=.. -raw comprehend_data_access_role_arn)
python3 run_pii_redaction_job.py
```

This uploads the same files to `batch-input/`, starts a
`StartPiiEntitiesDetectionJob` with `Mode=ONLY_REDACTION`, polls until it
completes (batch jobs typically take a few minutes even for tiny inputs),
then prints each file's original text next to its redacted copy from
`batch-output/`. You should see things like `[NAME]` and `[EMAIL]` in place
of the real values in `negative_feedback_with_pii.txt`.

## Cost notes

Everything here is pay-per-use with **no standing hourly charge** - no NAT
gateway, no provisioned throughput, no VPC, no always-on compute. Cost scales
with how many times you run the scripts, not with how long the stack stays
deployed.

| Component | Cost driver | Est. cost for one full run |
|---|---|---|
| Comprehend real-time Detect* | $0.0001 / 100-char unit, 3-unit (300-char) minimum per call; 5 calls x 4 tiny docs | ≈ $0.006 |
| Comprehend async PII redaction job | Same per-unit rate, billed per document processed | fractions of a cent |
| Lambda | 4 invocations, <1s each, 256MB | ~$0 (free tier) |
| S3 | A dozen tiny objects, PUT/GET requests | ~$0 |
| CloudWatch Logs | KBs of log output, 7-day retention | ~$0 |
| IAM | n/a | $0 |

**Total for a full run of both scripts: well under $0.05.** Re-running the
scripts repeatedly while experimenting still stays in the low cents. Leaving
the stack deployed between sessions only costs the negligible S3/CloudWatch
storage of a few KB - fractions of a cent per month. Check the current
[Comprehend pricing page](https://aws.amazon.com/comprehend/pricing/) if
you're running much larger or more numerous documents than the four samples
here.

## Clean up

```bash
tofu destroy
```

The bucket has `force_destroy = true` so OpenTofu removes the sample and
generated objects (including anything left under `batch-output/`) along with
it.

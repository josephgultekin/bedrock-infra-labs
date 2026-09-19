# Model governance evidence lab (vessel maintenance summarizer)

Demonstrates the exam's correct answer as a real pipeline: SageMaker Model Cards
created and versioned through the API, imported registry content validated
*before* approval, and a separate Glue-based path for data provenance.

```
Terraform provisions:
  - SageMaker Model Package Group + one versioned Model Package (metadata only)
  - S3 bucket with a sample vessel-incident dataset
  - Glue database + on-demand crawler over that dataset
  - CloudWatch log group for runtime decision events
  - An IAM policy documenting the permissions the scripts need

scripts/governance_pipeline.py walks the Model Card through:
  Draft -> (validate + enrich imported fields) -> PendingReview -> Approved
  -> a follow-up revision -> list version history -> log a runtime event

scripts/run_glue_crawler.py runs the crawler and prints the inferred schema.
```

Unlike the first two labs, there's no live HTTP traffic here - this mirrors a
CI/CD pipeline step, so it's a script you run, not an API you call from curl.

## Why two Lambdas or scripts instead of one

The exam question's key discriminator is that imported Model Registry content
"can be missing or inaccurate" and must be validated before approval - not
just automated. `governance_pipeline.py` makes that step explicit: it reads
the registry entry, shows what's actually missing (no risk rating, no
business context - that's not what the registry is for), fills those fields
in deliberately, *then* approves both the model package and the model card.
Compare this to the wrong answers in the question, which either skip the
validation step or use a flat PDF export as the artifact of record instead of
the versioned, schema-compliant API content.

## Prerequisites

1. Terraform >= 1.6 and AWS credentials able to create IAM roles, S3, Glue,
   SageMaker Model Registry/Model Card, and CloudWatch Logs resources.
2. Python 3.9+ and `pip install -r scripts/requirements.txt` (just boto3).
3. SageMaker Model Cards is unavailable in AWS GovCloud (US) - use a standard
   commercial region (default here is `us-east-1`).

As with the other labs, this was written carefully but not validated against
a live AWS account or the Terraform Registry in this sandbox (no network path
to `registry.terraform.io` here). The `aws_sagemaker_model_package` resource
in particular is a less commonly used one - run `terraform validate` /
`terraform plan` first, and check the `inference_specification` block against
the current AWS provider docs if `apply` complains about required fields.

## Run it

```bash
terraform init
terraform plan
terraform apply
```

```bash
cd scripts
pip install -r requirements.txt

export MODEL_PACKAGE_ARN=$(terraform output -chdir=.. -raw model_package_arn)
export RUNTIME_LOG_GROUP=$(terraform output -chdir=.. -raw runtime_events_log_group)
export GLUE_CRAWLER_NAME=$(terraform output -chdir=.. -raw glue_crawler_name)
export GLUE_DATABASE_NAME=$(terraform output -chdir=.. -raw glue_database_name)
```

> Your AWS identity needs the permissions in the `governance_pipeline_policy_arn`
> output attached (or equivalent) to run these scripts.

### Governance evidence (Model Cards)

```bash
python3 governance_pipeline.py
```

Watch the numbered steps in the output. Step 8 lists every version of the
card with its status and timestamp - that's the "preserve a review history as
artifacts change" requirement made concrete. Step 9 writes one runtime
decision event to CloudWatch Logs, tagged with the model card version it was
generated under, showing how operational events tie back to a specific
governance artifact version without living inside that artifact.

You can also open **SageMaker -> Governance -> Model cards** in the console
afterward to see the same version history and content visually.

### Data provenance (Glue)

```bash
python3 run_glue_crawler.py
```

Prints the columns the crawler inferred from `sample_incidents.csv` and the
table's create/update timestamps in the Data Catalog - the lineage-adjacent
metadata that a resource tag could never carry.

### Inspect the runtime event log directly

```bash
aws logs tail "$(terraform output -chdir=.. -raw runtime_events_log_group)" --since 1h
```

## Cost notes

Everything is pay-per-use. The Model Package Group/Package and Model Card API
calls carry no compute cost - nothing is ever trained or hosted. The Glue
crawler is the only line item with a real (if tiny) per-run cost, charged in
DPU-hours for the few minutes it takes to scan one small CSV - a few cents at
most, and it's on-demand only (no schedule attached), so it only runs when
you invoke it. S3, CloudWatch Logs, and IAM carry no meaningful cost at this
scale.

## Clean up

```bash
terraform destroy
```

`force_destroy = true` on the S3 bucket lets this remove the sample dataset
along with everything else. Note that `terraform destroy` will remove the
Model Package Group/Package and the CloudWatch log group, but **not** the
Model Card created by the Python script - that's a script-managed resource,
not a Terraform-managed one. Delete it separately if you want a fully clean
account:

```bash
aws sagemaker delete-model-card --model-card-name vessel-maintenance-summarizer
```

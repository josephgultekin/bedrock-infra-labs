# RAG metadata filtering lab (agricultural equipment compliance assistant)

Demonstrates the exam's correct answer - `.metadata.json` sidecar files, typed
metadata attributes, and one logical `RetrievalFilter` expression - against a
real Bedrock Knowledge Base, using **S3 Vectors** as the vector store because
it carries no idle/hourly cost (unlike OpenSearch Serverless, which runs
roughly $0.24/hour just by existing).

## Where this lab honestly deviates from the exam's literal answer

I researched current AWS docs before building this, and found two things
worth being upfront about:

**1. S3 Vectors doesn't support `STRING_LIST` metadata (as of this writing).**
AWS's own knowledge-base-setup documentation states plainly that "Amazon S3
vector indexes support string, boolean, and number types" - no list type.
The exam's correct answer calls for `STRING_LIST` to hold multiple product
families per document. That's real advice for OpenSearch Serverless, Aurora
PostgreSQL, or Pinecone-backed knowledge bases - just not for S3 Vectors,
which is the tradeoff you asked to make for cost.

So this lab does the closest honest equivalent: each document has **one**
`product_family` as a scalar `STRING`, and "authorized product families" is
enforced at *query time* with the `in` operator against a list of allowed
values - which works fine on scalar STRING metadata, since the list lives in
the filter, not on the document. This satisfies the actual requirement
("limit results to authorized product families") without needing list-typed
metadata at all. If your real documents can belong to multiple product
families *simultaneously*, that's the case where you'd genuinely need
`STRING_LIST` and a different vector store.

**2. `metadataFilesPrefix` doesn't appear to be a literal current API field.**
The current `S3DataSourceConfiguration` only documents `BucketArn`,
`BucketOwnerAccountId`, and `InclusionPrefixes` - I couldn't find a field
named `metadataFilesPrefix` in current CloudFormation/Terraform schemas. The
underlying *mechanism* the exam is testing is real and unchanged: a
`<file>.metadata.json` sidecar stored next to its source document, discovered
by naming convention during ingestion. That's exactly what this lab builds
(`s3_source.tf`). The parameter name in the question may be exam-specific
terminology rather than something you'll find in the current SDK.

Both of these are called out inline in the Terraform comments too.

## What gets built

```
S3 bucket (bulletins/) --> 4 sample service bulletins, each with a
                            <file>.txt.metadata.json sidecar (product_family
                            STRING, authoring_team STRING, effective_date NUMBER)
        |
        v
Bedrock Knowledge Base (S3 data source) --> S3 Vectors (vector bucket + index)
        |
        v
scripts/query_with_filters.py runs Retrieve() with progressively combined
RetrievalFilter expressions to prove each requirement
```

The four sample bulletins are deliberately spread out so the filters have
something real to exclude:

| File | product_family | authoring_team | effective_date |
|---|---|---|---|
| tractor-hydraulic-2026 | Tractors | Powertrain | 2026-01-15 |
| combine-sensor-2026 | Combines | Electronics | 2026-06-01 |
| tractor-brake-2025 | Tractors | Chassis | 2025-03-10 *(older)* |
| sprayer-nozzle-2026 | Sprayers | Powertrain | 2026-03-20 *(different family)* |

## Prerequisites

1. Terraform >= 1.6 and an AWS provider that supports `aws_s3vectors_*`
   resources (>= 6.24.0, pinned in `versions.tf`).
2. **Bedrock model access enabled** for `amazon.titan-embed-text-v2:0` in your
   target region (Bedrock console -> Model access).
3. S3 Vectors and Bedrock Knowledge Bases availability varies by region -
   `us-east-1` and `us-west-2` are safe bets; check current availability if
   you use a different region.
4. Python 3.9+ and `pip install -r scripts/requirements.txt`.

As with the other labs: written carefully, not validated against a live
account or the Terraform Registry in this sandbox. S3 Vectors' Terraform
support is also comparatively recent - run `terraform validate` / `plan`
first, and double check the `aws_bedrockagent_knowledge_base` storage block
and the S3 Vectors IAM actions in `iam.tf` against current docs if `apply` or
the ingestion sync throws an error.

## Run it

```bash
terraform init
terraform plan
terraform apply
```

```bash
cd scripts
pip install -r requirements.txt

export KNOWLEDGE_BASE_ID=$(terraform output -chdir=.. -raw knowledge_base_id)
export DATA_SOURCE_ID=$(terraform output -chdir=.. -raw data_source_id)
```

### 1. Sync the data source (ingest + embed + write vectors)

```bash
python3 sync_data_source.py
```

Wait for `status=COMPLETE`. This is the step that actually reads the
`.metadata.json` sidecars and attaches typed attributes to each vector.

### 2. Run the filtered queries

```bash
python3 query_with_filters.py
```

Five scenarios run in sequence, each printing which bulletins survived:

1. No filter - all four are candidates.
2. `in` on `product_family` - the Sprayers bulletin drops out.
3. `equals` on `authoring_team` - only Powertrain-authored bulletins remain.
4. `greaterThanOrEquals` on `effective_date` - the 2025 brake bulletin drops out.
5. All three combined inside one `andAll` - only `tractor-hydraulic-2026`
   should survive every condition.

Step 5 is the one that directly demonstrates the tested constraint: it's a
single top-level `RetrievalFilter` member (`andAll`) with everything else
nested inside it, not several independent top-level filters.

## A real gotcha worth knowing if you extend this

S3 Vectors caps filterable metadata at roughly 2 KB per vector, and Bedrock's
internal chunk-text/metadata-blob keys count against that by default - which
routinely throws `ValidationException` during ingestion once your chunks get
larger. `s3vectors.tf` already marks `AMAZON_BEDROCK_TEXT` and
`AMAZON_BEDROCK_METADATA` as non-filterable to avoid this; keep that if you
add larger source documents.

## Cost notes

S3 Vectors has no standing/hourly charge - you pay for storage and requests,
both trivial at this scale. The only real per-call cost is the Titan
embedding calls during sync (four tiny documents) and during each `Retrieve`
query - fractions of a cent total. Compare this to an OpenSearch Serverless
backend, which bills a minimum OCU-hour regardless of usage the moment it
exists.

## Clean up

```bash
terraform destroy
```

`force_destroy = true` on the source bucket handles the sample documents.
Destroying the knowledge base also removes its data source; the S3 Vectors
bucket/index are separate resources and are destroyed alongside everything
else in this stack.

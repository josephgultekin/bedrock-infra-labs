# Prompt governance lab (pharmacovigilance adverse event summarizer)

Demonstrates the exam's correct answer end to end: reviewed source files in
versioned S3, a Bedrock Prompt Management prompt with `{{variable}}`
placeholders, production releases as immutable prompt **versions** (not
"Save as draft"), invocation via the prompt ARN as `modelId`, and both
CloudTrail (API audit) and model invocation logging (runtime content)
kept in the same account and Region.

```
source_prompts/*.txt (reviewed, change-management-approved templates)
        |
        v
S3 bucket, Versioning enabled  <-- requirement 1: reviewed source files retained
        |
        v  (scripts/publish_approved_prompt.py)
Bedrock Prompt Management prompt, {{variable}} placeholders
        |
        v  create_prompt_version()
Prompt VERSION (immutable snapshot)  <-- requirement 2: point-in-time snapshots
        |
        v  (scripts/invoke_prompt.py: modelId = version ARN, promptVariables={...})
Bedrock runtime
        |
        +--> CloudTrail (single-Region trail)      <-- requirement 3: API audit
        +--> CloudWatch Logs (same account/Region)  <-- requirement 4: invocation logs
```

## An important confidence flag on the Bedrock Prompt Management resource

`bedrock_prompt.tf` uses `aws_bedrockagent_prompt` and
`aws_bedrockagent_prompt_version`, which are real, current Terraform AWS
provider resources (confirmed present in provider docs). However, the
Terraform Registry's resource-reference page for `aws_bedrockagent_prompt`
is JavaScript-rendered and I couldn't load its exact attribute/block names
in this sandbox. What's written here is reconstructed from the underlying
`AWS::Bedrock::Prompt` / `AWS::Bedrock::PromptVersion` CloudFormation schema,
which **is** authoritative for the data model - variant name, template type,
`{{variable}}` input variables, inference config - even if a block name here
or there (e.g. `variant` vs. some other block name) turns out to differ
slightly from the Terraform provider's exact HCL naming.

**Run `terraform plan` before `apply` and expect to possibly need a small
attribute-name correction.** If `plan` reports an "unsupported argument"
error, that error message will name the actual expected argument - check it
against `terraform providers schema -json | grep -A 30 bedrockagent_prompt`
or the current registry page. This is a newer, less-traveled resource than
anything in the earlier labs, so it's the one most worth this extra caution.

## Prerequisites

1. Terraform >= 1.6 and an AWS provider version that includes
   `aws_bedrockagent_prompt` (pinned to `~> 6.34` in `versions.tf`).
2. **Bedrock model access enabled** for `anthropic.claude-3-5-haiku-20241022-v1:0`
   in your target region (Bedrock console -> Model access).
3. Python 3.9+ and `pip install -r scripts/requirements.txt`.
4. If your account already has an existing CloudTrail trail, `aws_cloudtrail.this`
   here creates an additional, lab-scoped one - that's fine (multiple trails
   can coexist), but be aware it's not replacing anything you already have.

## Run it

```bash
terraform init
terraform plan
terraform apply
```

```bash
cd scripts
pip install -r requirements.txt

export PROMPT_ARN=$(terraform -chdir=.. output -raw prompt_arn)
export SOURCE_BUCKET=$(terraform -chdir=.. output -raw source_bucket)
export INVOCATION_LOG_GROUP=$(terraform -chdir=.. output -raw invocation_log_group)
export CLOUDTRAIL_NAME=$(terraform -chdir=.. output -raw cloudtrail_name)
export PROMPT_VERSION_ARN=$(terraform -chdir=.. output -raw initial_version_arn)
```

### 1. Invoke the initial version

```bash
python3 invoke_prompt.py
```

Uses the prompt version's ARN as `modelId` and passes the narrative through
`promptVariables` - the application code never sees or assembles the
template text itself.

### 2. Publish a change-management-approved edit

```bash
python3 publish_approved_prompt.py ../source_prompts/adverse_event_summary_v2.txt \
    --change-ticket CM-1002 \
    --description "Added reporter-type field per pharmacovigilance review."
```

This uploads the revised file (a new S3 object version), updates the Bedrock
prompt's working draft, and creates a new prompt **version** - the point-in-time
snapshot. Export the printed `PROMPT_VERSION_ARN` and re-run `invoke_prompt.py`
to see the updated output (now including the "Reporter type" section).

### 3. Check all four governance requirements at once

Wait a few minutes for CloudTrail and invocation-logging delivery, then:

```bash
python3 check_governance_evidence.py
```

This prints, in order: the S3 object version history, the Bedrock prompt
version history, recent CloudTrail events for `bedrock.amazonaws.com` API
calls, and the CloudWatch Logs streams from model invocation logging -
one check per requirement in the exam question.

## Why this isn't "Save as draft"

If you want to see the trap the exam question is testing, open the prompt
in the Bedrock console, use **Compare** to create a couple of variants, then
choose **Save as draft** on one of them - the others disappear immediately.
That's fine for iterating on a prompt, but it's not a retention mechanism.
`publish_approved_prompt.py` never touches that action; it goes straight to
`create_prompt_version`, which is what actually persists history.

## Cost notes

Nothing here has a standing cost. S3, CloudWatch Logs, CloudTrail (one
trail, standard event logging), and Bedrock Prompt Management itself carry
no idle charge. The only real per-call cost is the Bedrock model
invocations from `invoke_prompt.py` - a couple of short Claude Haiku calls,
fractions of a cent. CloudTrail's first copy of management events is free;
this lab creates exactly one trail.

## Clean up

```bash
terraform destroy
```

Both S3 buckets have `force_destroy = true` so their versioned/logged
objects don't block teardown. No standing charges exist in this stack, but
there's no reason to leave it up once you're done testing.

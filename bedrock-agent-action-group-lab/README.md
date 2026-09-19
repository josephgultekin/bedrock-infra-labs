# Bedrock agent action group lab (container pickup booking)

Demonstrates the exam's correct answer as a real agent: an action group with
an **OpenAPI schema in S3** giving the model a structured tool contract, and
a **Lambda executor** doing deterministic validation before anything reaches
the downstream scheduling API.

```
Bedrock Agent (Claude via Bedrock)
        |  reads tool contract from
        v
OpenAPI schema (S3) --> describes POST /pickup-appointments:
                         terminal_id (string), appointment_time (date-time),
                         container_type (enum) - all required
        |
        v
Action group --> Lambda executor (booking_validator)
                    |
                    +-- missing/invalid field? --> 400, rejected here.
                    |   Mock scheduling API is never called.
                    |
                    +-- valid? --> invokes mock_scheduling_api Lambda
                                   (stands in for the internal scheduling API)
```

## Why this proves the tested concept, not just "an agent that works"

The exam question's real discriminator is whether invalid tool calls fail
*before* reaching the scheduling API, using a *structured* contract rather
than prompt guidance alone. `test_validator_directly.py` proves this
deterministically: it sends the validator Lambda three malformed requests
(missing `terminal_id`, a non-ISO `appointment_time`, an unsupported
`container_type` - the exact three failure modes named in the question) and
one valid request, then checks the mock scheduling API's CloudWatch logs to
confirm it was invoked exactly once - only for the valid request. The three
bad ones never got anywhere near it.

This sidesteps a real limitation of testing agents end-to-end: whether the
model *phrases* a malformed tool call at all is nondeterministic. Testing the
Lambda executor directly, with the same event shape Bedrock actually sends,
proves the enforcement layer works regardless of what the model does -
which is precisely the point of putting validation in Lambda instead of
relying on prompt instructions.

## Prerequisites

1. Terraform >= 1.6, and the **AWS CLI installed and configured** locally -
   the `null_resource.prepare_agent` step shells out to
   `aws bedrock-agent prepare-agent` (Bedrock agents need an explicit
   "prepare" step after any action group change before the DRAFT version
   picks it up; doing this via CLI avoids relying on undocumented ordering
   behavior of the agent resource's own `prepare_agent` flag).
2. **Bedrock model access enabled** for `anthropic.claude-3-5-haiku-20241022-v1:0`
   in your target region (Bedrock console -> Model access).
3. Python 3.9+ and `pip install -r scripts/requirements.txt`.

As with the other labs: written carefully, not validated against a live
account or the Terraform Registry in this sandbox. I did unit-test the
validator's actual Python logic locally (six cases, including all three
scenario failure modes) before shipping this - that logic is solid. What I
couldn't verify here is the Terraform resource schema for
`aws_bedrockagent_agent` / `aws_bedrockagent_agent_action_group` against a
live provider, so run `terraform validate` / `plan` first.

## Run it

```bash
terraform init
terraform plan
terraform apply
```

```bash
cd scripts
pip install -r requirements.txt

export VALIDATOR_FUNCTION_NAME=$(terraform output -chdir=.. -raw booking_validator_function_name)
export SCHEDULING_API_FUNCTION_NAME=$(terraform output -chdir=.. -raw mock_scheduling_api_function_name)
export AGENT_ID=$(terraform output -chdir=.. -raw agent_id)
```

### The deterministic proof

```bash
python3 test_validator_directly.py
```

You should see three `400` rejections with specific `error`/`details`
fields, one `200` with a `confirmation_id`, and a final count confirming the
downstream mock scheduling API was invoked exactly once.

### Optional: talk to the real agent

```bash
python3 invoke_agent.py "I need to book a pickup"
```

This uses Bedrock's built-in test alias (`TSTALIASID`), so no alias needs to
be created. The agent should ask you for the terminal ID, time, and
container type per its instructions before ever calling the tool - try
giving it an invalid terminal ID or a vague time and watch it relay the
Lambda's rejection back to you in conversation. This part is genuinely
nondeterministic (it's an LLM deciding what to ask and when), so don't treat
a single run as proof of anything - it's here to see the orchestration, not
to test it.

## Cost notes

Nothing here has a standing cost. Lambda, S3, and CloudWatch Logs are all
pay-per-use or free-tier at this scale. The only real per-call cost is
Bedrock model invocations - a handful of Claude Haiku calls if you run
`invoke_agent.py`, fractions of a cent each. `test_validator_directly.py`
doesn't invoke any foundation model at all, since it talks to the Lambda
directly.

## Clean up

```bash
terraform destroy
```

No standing charges exist in this stack, but there's no reason to leave it
up once you're done testing.

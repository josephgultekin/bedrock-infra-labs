# Bedrock AgentCore lab

A hands-on stack for Amazon Bedrock AgentCore's four pieces that matter most
once you're past a toy demo: a **Gateway** that exposes tools over MCP, a
**Runtime** that hosts the agent container, **Identity** for fetching
credentials a tool needs, and **Policies** for governing what's allowed.
The agent image is built and pushed to ECR by a GitHub Actions workflow
(OIDC, no stored AWS keys), and everything - the Runtime and the Lambda
tools behind the Gateway - runs in private subnets of a dedicated,
non-default VPC.

```
GitHub Actions (OIDC, no static keys)
   build + push agent image
         |
         v
   ECR repo: <project>-agent
         |
         v  (container_uri)
   AgentCore Runtime  ---VPC mode (private subnets)---+
   (hosts the agent)                                   |
         | InvokeGateway                                |
         v                                               |
   AgentCore Gateway (MCP, AWS_IAM authorizer)           |
         | gateway_iam_role credential passthrough        |
         v                                               |
   Gateway Targets --> Lambda tools (private subnets) <--+
   - list_products            (pure mock data)
   - get_order_status         (also calls AgentCore Identity's
                                GetResourceApiKey to fetch a demo
                                credential - proves Identity wiring)

   AgentCore Identity: Workload Identity (for the Runtime) +
                        API Key Credential Provider (for get_order_status)

   AgentCore Policies: Policy Engine + one illustrative Cedar Policy

Non-default VPC (10.42.0.0/16), 2 AZs:
   public subnets  -> IGW                  (NAT instance lives here)
   private subnets -> 0.0.0.0/0 via NAT instance ENI
```

The Gateway itself has no subnet placement - it's an AWS-managed endpoint,
the same way API Gateway is. Only the Lambda tools and the Runtime's VPC
attachment actually sit inside the private subnets.

## Intentional deviation from this repo's usual convention

The root README says labs favor "no NAT gateways... no idle compute." This
lab's **NAT instance** (t4g.nano, not a NAT Gateway) is a deliberate
exception, because the point of this lab is specifically to get hands-on
with the NAT-instance pattern. It does carry a small standing cost - see
Cost notes.

## Prerequisites

1. OpenTofu >= 1.6 (or Terraform >= 1.6) and the AWS CLI configured with
   credentials that can create VPCs, EC2 instances, IAM roles, Lambda, ECR,
   and Bedrock AgentCore resources (used `AWS_PROFILE=dops` throughout
   development of this lab).
2. A region where Bedrock AgentCore is available (default here is
   `us-east-1`).
3. Docker, if you want to build/push the agent image locally instead of via
   GitHub Actions.
4. **To use the GitHub Actions workflow**: a GitHub OIDC provider for
   `token.actions.githubusercontent.com` in your account. This is an
   **account-wide singleton** - check first with
   `aws iam list-open-id-connect-providers --profile dops`. If one already
   exists, leave `create_github_oidc_provider = false` (the default) and set
   `existing_github_oidc_provider_arn` instead; only flip it to `true` if
   none exists yet.

This was authored carefully, with `tofu init`/`tofu validate`/`tofu plan`
run against a live account, but **not yet with a full `apply`**. Bedrock
AgentCore only reached GA in 2025, and one specific gap couldn't be closed
from this sandbox - see "Unverified against live AWS docs" below. Read that
section before you `apply`.

## What gets built

- A non-default VPC, 2 public + 2 private subnets across 2 AZs, an Internet
  Gateway, and a single t4g.nano **NAT instance** (not a NAT Gateway) that
  the private subnets route `0.0.0.0/0` through.
- An ECR repo for the agent image, plus a GitHub Actions workflow
  (`.github/workflows/build-push-agentcore-image.yml`) that builds and
  pushes it via OIDC - no AWS access keys stored in GitHub.
- An **AgentCore Gateway** (MCP, `AWS_IAM` authorizer) with two targets
  backed by Lambda: `list_products` (static mock data) and
  `get_order_status` (also fetches a demo credential from AgentCore
  Identity, to prove that wiring). Both Lambdas run in the private subnets.
- **AgentCore Identity**: a workload identity for the Runtime, and an API
  key credential provider that `get_order_status` reads from.
- An **AgentCore Runtime** running in the private subnets (`network_mode =
  "VPC"`), hosting the agent container pulled from ECR.
- **AgentCore Policies**: a policy engine and one illustrative (permissive
  placeholder) Cedar policy - see the caveat in `policy.tf`.

## Unverified against live AWS docs

Bedrock AgentCore's Terraform support (resource names, argument shapes) was
confirmed against the `hashicorp/terraform-provider-aws` source on GitHub
directly, and `tofu validate`/`tofu providers schema -json` against the
real installed provider (v6.69.1) caught and fixed several wrong attribute
names and an invalid nested-block shape during development - so the shape
of the HCL below is now confirmed against ground truth, not just the
provider's published docs. What this sandbox could **not** fetch was AWS's
live Service Authorization Reference page, so the following IAM-level
details are still this repo's best-guess pattern-matches, not confirmed
strings - double-check each one before `apply` (a wrong IAM action name
won't fail `tofu plan`, only `apply` or the actual agent run):

- The trust principal `bedrock-agentcore.amazonaws.com` used in
  `gateway.tf` and `runtime.tf`'s assume-role policies.
- The IAM action names `bedrock-agentcore:InvokeGateway`,
  `bedrock-agentcore:GetWorkloadAccessToken`, and
  `bedrock-agentcore:GetResourceApiKey`.
- The `get_order_status` Lambda's boto3 call
  (`boto3.client("bedrock-agentcore").get_resource_api_key(...)`).
- The agent container's HTTP contract in `agent/app.py` (the
  `bedrock-agentcore` Python SDK's `BedrockAgentCoreApp` API and port 8080).
- `gateway.tf`'s `policy_engine_configuration.mode = "ENFORCE"` - the real
  schema confirms this block and its `arn`/`mode` arguments exist, but the
  valid values for `mode` weren't confirmed.
- `policy.tf`'s Cedar statement is an intentionally permissive placeholder,
  not a real rule - AgentCore's actual Cedar entity/action schema wasn't
  confirmed.

(The Gateway's MCP endpoint URL, previously a guess, is now the confirmed
`gateway_url` output - no CLI round-trip needed to use
`scripts/invoke_gateway_tool.py`.)

Check the IAM items against
[AWS's Service Authorization Reference](https://docs.aws.amazon.com/service-authorization/latest/reference/reference_policies_actions-resources-contextkeys.html)
and the `bedrock-agentcore` SDK's own docs before relying on this beyond
this lab.

## Run it

Because the AgentCore Runtime needs a real image in ECR before it can be
created, this is a **two-phase apply**:

### 1. Networking, ECR, IAM, Gateway, Identity, Policies

```bash
tofu init
tofu plan
tofu apply
```

This creates everything except a *working* Runtime - `agent_image_tag`
defaults to `"placeholder"`, so the Runtime resource is created pointing at
an image that doesn't exist yet. (If AgentCore validates image existence at
creation time rather than at invocation time, this step may need to exclude
the Runtime via `-target` instead - see `variables.tf`'s comment on
`agent_image_tag`.)

### 2. Build and push the agent image

Either let GitHub Actions do it:

```bash
# One-time repo setup:
gh variable set AWS_ROLE_ARN --body "$(tofu output -raw github_actions_role_arn)"
gh variable set ECR_REPOSITORY_URL --body "$(tofu output -raw ecr_repository_url)"

# Then push a change under bedrock-agentcore-lab/agent/, or:
gh workflow run build-push-agentcore-image.yml
```

...or build and push locally:

```bash
cd agent
aws ecr get-login-password --region us-east-1 --profile dops | \
  docker login --username AWS --password-stdin "$(tofu output -chdir=.. -raw ecr_repository_url | cut -d/ -f1)"
docker build -t "$(tofu output -chdir=.. -raw ecr_repository_url):latest" .
docker push "$(tofu output -chdir=.. -raw ecr_repository_url):latest"
```

### 3. Point the Runtime at the real image

```bash
tofu apply -var="agent_image_tag=latest"
```

### 4. Test it

```bash
cd scripts
pip install -r requirements.txt

export AGENT_RUNTIME_ARN=$(tofu output -chdir=.. -raw agent_runtime_arn)
python3 invoke_agent_runtime.py "What products do you have?"
```

To test the Gateway's tools directly (bypassing the Runtime), see the setup
instructions in `scripts/invoke_gateway_tool.py` - it needs the Gateway's
real MCP URL, fetched via the AWS CLI, not guessed.

## Cost notes

Unlike most labs in this repo, this one has a **small standing hourly
cost** while deployed - the NAT instance and its public IP - on top of
pay-per-use AgentCore charges.

| Component | Cost driver | Est. cost |
|---|---|---|
| NAT instance (t4g.nano) | Runs continuously while the stack is deployed | ≈ $3.06/month ($0.0042/hr) |
| Elastic IP (public IPv4) | AWS bills **all** public IPv4 addresses since Feb 2024, including EIPs attached to a running instance - this is no longer free | ≈ $3.65/month ($0.005/hr) |
| ECR | Image storage, a few hundred MB | ~$0.01-0.03/month |
| AgentCore Gateway / Runtime / Identity / Policies | Newer services (2025 GA), consumption-based - no confident per-unit rate to quote here, check [Bedrock pricing](https://aws.amazon.com/bedrock/pricing/) | likely well under $1 for light manual testing |
| Lambda tools | A handful of sub-second invocations per test | ~$0 (free tier) |
| CloudWatch Logs | KBs of log output, 7-day retention | ~$0 |

**Total standing cost while deployed: ≈ $6.71/month (≈ $0.22/day)**, dominated
by the NAT instance and its public IP - both bill whether or not you're
actively testing anything.

**Don't leave this deployed between sessions** - the NAT instance and its
public IP keep billing even when you're not testing anything, unlike every
other lab here.

## Clean up

```bash
tofu destroy
```

If you set `create_github_oidc_provider = true`, the OIDC provider is
account-wide and other stacks may depend on it - `destroy` will remove it
along with everything else in this lab's state, so only set that variable
to `true` if this lab is the one that should own it.

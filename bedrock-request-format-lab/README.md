# Bedrock Request-Schema Lab

Hands-on lab for the exam concept behind Q1 / Q36 (mock exams): **Amazon Bedrock
Runtime's `InvokeModel` is a common HTTP operation, but the JSON request body
is model-specific, not universal.** This lab deploys a Lambda function that
lets you send both the *correct* and *intentionally broken* request shapes to
two Bedrock models, so you can see the actual `ValidationException` errors
instead of just reading about them.

Models used:
- **Amazon Titan Text Embeddings V2** (`amazon.titan-embed-text-v2:0`)
- **Anthropic Claude 3.5 Sonnet** (`anthropic.claude-3-5-sonnet-20241022-v2:0`)

## Prerequisites

1. An AWS account with Terraform (>= 1.5) and the AWS CLI configured.
2. **Model access enabled** for both models above in the Bedrock console,
   in the region you deploy to (default: `us-east-1`). Bedrock model access
   is opt-in per account/region under *Bedrock console → Model access*.
3. If your account requires **cross-Region inference profiles** for Claude
   3.5 Sonnet (common in newer accounts), replace the `claude_model_id`
   variable with the inference profile ARN/ID instead of the raw model ID,
   and update the IAM policy's `Resource` in `main.tf` accordingly
   (inference profile ARNs look like
   `arn:aws:bedrock:<region>:<account-id>:inference-profile/us.anthropic.claude-3-5-sonnet-...`).

## Deploy

```bash
cd bedrock-request-format-lab
terraform init
terraform apply
```

Terraform will:
- Create an IAM role for the Lambda function, scoped to `bedrock:InvokeModel`
  on only the two model ARNs used in this lab (least privilege, not `*`).
- Zip up `lambda/handler.py` automatically and deploy it as a Python 3.12
  Lambda function.

Note the `function_name` output when it finishes.

## Run the lab

Each test event has a `target` (`embedding` or `claude`) and a `mode`
(`correct` or one of the broken variants). Invoke with the AWS CLI:

```bash
# 1. Correct Titan Embeddings request -- should succeed
aws lambda invoke --function-name bedrock-request-format-lab \
  --cli-binary-format raw-in-base64-out \
  --payload file://test-events/correct-embedding.json out.json && cat out.json | python3 -m json.tool

# 2. Broken: Claude's messages format sent to Titan Embeddings -- should fail
aws lambda invoke --function-name bedrock-request-format-lab \
  --cli-binary-format raw-in-base64-out \
  --payload file://test-events/broken-embedding-messages-format.json out.json && cat out.json | python3 -m json.tool

# 3. Correct Claude Messages API request -- should succeed
aws lambda invoke --function-name bedrock-request-format-lab \
  --cli-binary-format raw-in-base64-out \
  --payload file://test-events/correct-claude.json out.json && cat out.json | python3 -m json.tool

# 4. Broken: legacy Human:/Assistant: completion format sent to Claude 3.5 Sonnet -- should fail
aws lambda invoke --function-name bedrock-request-format-lab \
  --cli-binary-format raw-in-base64-out \
  --payload file://test-events/broken-claude-legacy-completion.json out.json && cat out.json | python3 -m json.tool

# 5. Broken: Titan's inputText/textGenerationConfig shape sent to Claude -- should fail
aws lambda invoke --function-name bedrock-request-format-lab \
  --cli-binary-format raw-in-base64-out \
  --payload file://test-events/broken-claude-titan-generic-shape.json out.json && cat out.json | python3 -m json.tool
```

Each response includes `request_body_sent` so you can see exactly what was
sent alongside the result -- either a real embedding vector / generated
answer (`outcome: success`), or the actual `ValidationException` message
Bedrock returns (`outcome: error`), including `error_code` and
`error_message`.

## What to look for

| Test | Model called | Body shape sent | Expected result |
|---|---|---|---|
| 1 | Titan Embeddings V2 | `{"inputText": "..."}` | Success — real embedding vector |
| 2 | Titan Embeddings V2 | `{"messages": [{"role": "user", ...}]}` | `ValidationException` — Titan has no `messages` field |
| 3 | Claude 3.5 Sonnet | `{"anthropic_version", "max_tokens", "messages": [...]}` | Success — generated answer |
| 4 | Claude 3.5 Sonnet | `{"prompt": "\n\nHuman: ...", "max_tokens_to_sample": ...}` | `ValidationException` — that's the *old* completion API, not Messages API |
| 5 | Claude 3.5 Sonnet | `{"inputText": "...", "textGenerationConfig": {...}}` | `ValidationException` — that's Titan's text-gen shape, not Claude's |

Try editing `test-events/*.json` with your own `query` / `context` /
`question` values, or add a new mode to `lambda/handler.py` to experiment
further (e.g. try Titan Embeddings' optional `dimensions` field, or omit
`max_tokens` from the correct Claude body and see what error comes back).

## Cost note

Each successful invocation costs a small amount for the actual Titan
Embeddings / Claude 3.5 Sonnet inference call. Failed (`ValidationException`)
calls are rejected before inference and are not billed as model usage.

## Clean up

```bash
terraform destroy
```

# GenAI/Bedrock hands-on labs

Throwaway AWS infrastructure for getting hands-on experience with Amazon
Bedrock and related AWS AI services (Comprehend, SageMaker, Glue, etc.).
Each lab is a **self-contained OpenTofu/Terraform stack** in its own
directory: spin it up, poke at it, tear it down. Nothing here is meant to
run long-term.

## Labs

| Lab | What it's for |
|---|---|
| [bedrock-agent-action-group-lab](bedrock-agent-action-group-lab/) | A real Bedrock agent action group: OpenAPI schema in S3 + a Lambda executor doing deterministic validation before anything reaches a booking API. |
| [bedrock-guardrail-lab](bedrock-guardrail-lab/) | API Gateway -> Lambda -> Bedrock Converse with a Guardrail, redacted audit trail, and an EventBridge/Step Functions compliance-review path on intervention. |
| [bedrock-preflight-guardrail-lab](bedrock-preflight-guardrail-lab/) | A synchronous moderation gate (custom policy check + Bedrock Guardrails) that runs entirely *before* any model or agent is invoked. |
| [bedrock-prompt-governance-lab](bedrock-prompt-governance-lab/) | Versioned source prompts in S3, Bedrock Prompt Management with `{{variable}}` placeholders, and immutable production prompt versions. |
| [bedrock-request-format-lab](bedrock-request-format-lab/) | Shows that `InvokeModel`'s request body is model-specific, not universal, via a Lambda exercised against both correct and deliberately broken request shapes. |
| [bedrock-streaming-latency-lab](bedrock-streaming-latency-lab/) | Converse vs. ConverseStream, instrumented with `TimeToFirstToken` and `InvocationLatency` CloudWatch metrics/alarms. |
| [comprehend-document-insights-lab](comprehend-document-insights-lab/) | Amazon Comprehend end to end: an S3-triggered Lambda doing real-time sentiment/entities/key-phrases/PII detection, plus an async `StartPiiEntitiesDetectionJob` batch redaction job with its own IAM data-access role. |
| [model-governance-evidence-lab](model-governance-evidence-lab/) | SageMaker Model Cards created/versioned through the API, registry content validated before approval, and a Glue-based data-provenance path. |
| [rag-metadata-filtering-lab](rag-metadata-filtering-lab/) | A real Bedrock Knowledge Base backed by S3 Vectors, using `.metadata.json` sidecars and `RetrievalFilter` expressions to scope retrieval. |

## Conventions

- **Directory per lab**, named `<topic>-lab/`, each independently
  `init`/`plan`/`apply`/`destroy`-able - no shared state or cross-lab
  dependencies.
- **OpenTofu** is the preferred CLI (`tofu init`, `tofu plan`, `tofu apply`,
  `tofu destroy`); the configs are plain HCL and also work with Terraform if
  that's what you have installed.
- Every lab's own `README.md` has an architecture diagram, prerequisites
  (including any one-time Bedrock model-access console step), a "Run it"
  walkthrough, cost notes, and a "Clean up" section - read that before
  `apply`.
- Labs favor **no standing hourly cost** where possible (no NAT gateways, no
  provisioned throughput, no idle compute) and use `force_destroy = true` on
  S3 buckets so `destroy` doesn't get stuck on leftover objects.
- **Always run `tofu destroy` when you're done** with a lab - there's no
  reason to leave any of this running.

## Prerequisites (all labs)

- OpenTofu >= 1.6 (or Terraform >= 1.6) and the AWS CLI, configured with
  credentials for an account you're comfortable creating/destroying
  resources in (IAM roles, Lambda, S3, and whatever else that lab needs).
- Python 3.9+ for the labs that ship demo/driver scripts under `scripts/`.
- Some labs require a one-time **Bedrock model access** grant in the target
  region (Bedrock console -> Model access) before `apply` will work - check
  the individual lab's README.

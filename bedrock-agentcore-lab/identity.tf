# AgentCore Identity: a workload identity for the Runtime, and an API key
# credential provider that the get_order_status Lambda tool fetches from -
# proving the Identity wiring works end to end, even though the "external
# API" here is just a demo placeholder (see variables.tf).

resource "aws_bedrockagentcore_workload_identity" "agent" {
  name = "${var.project_name}-agent-identity"
}

resource "aws_bedrockagentcore_api_key_credential_provider" "sample_tool" {
  name = "${var.project_name}-sample-tool-api-key"

  # The provider also supports a write-only `api_key_wo` argument so the
  # secret never lands in state at all. Skipped here to keep this demo
  # simple - swap to api_key_wo if you wire this up to a real credential.
  api_key = var.sample_tool_api_key
}

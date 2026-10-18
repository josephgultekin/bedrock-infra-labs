# AgentCore Policies: a Policy Engine plus one illustrative Cedar policy.
#
# NOTE (unverified - see README): this is the most speculative resource in
# the stack. AgentCore's actual Cedar entity/action schema (what principal,
# action, and resource types it exposes to a policy) wasn't confirmed
# against live AWS docs - the statement below is a deliberately permissive
# placeholder, not a meaningful access rule. validation_mode is set to
# IGNORE_ALL_FINDINGS so a schema mismatch doesn't block `apply`; switch to
# the default FAIL_ON_ANY_FINDINGS once you've confirmed the real entity
# types and written a statement that actually restricts something.

resource "aws_bedrockagentcore_policy_engine" "this" {
  name        = replace(var.project_name, "-", "_")
  description = "Policy engine for the ${var.project_name} sample agent."
}

resource "aws_bedrockagentcore_policy" "tool_guardrail" {
  name             = "${replace(var.project_name, "-", "_")}_tool_guardrail"
  policy_engine_id = aws_bedrockagentcore_policy_engine.this.policy_engine_id
  description      = "Placeholder permit-all rule - replace once AgentCore's real Cedar schema is confirmed."
  validation_mode  = "IGNORE_ALL_FINDINGS"

  definition {
    cedar {
      statement = <<-CEDAR
        permit (
          principal,
          action,
          resource
        );
      CEDAR
    }
  }
}

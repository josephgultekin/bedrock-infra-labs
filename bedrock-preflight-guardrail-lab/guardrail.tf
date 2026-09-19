resource "aws_bedrock_guardrail" "preflight" {
  name                      = "${var.project_name}-guardrail"
  description               = "Preflight-only guardrail: evaluated via ApplyGuardrail before any model or agent runs"
  blocked_input_messaging   = "This request cannot be processed due to safety policy restrictions."
  blocked_outputs_messaging = "This response cannot be returned due to safety policy restrictions."

  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    # Jailbreak / prompt-injection detection. Bedrock only evaluates this on the
    # input side, so output_strength must be NONE.
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }

  # A deterministic custom word so a guardrail-triggered rejection can be tested
  # reliably, without depending on the jailbreak heuristic firing on a specific phrasing.
  word_policy_config {
    words_config {
      text = "TESTVIOLATION"
    }
  }
}

resource "aws_bedrock_guardrail_version" "preflight" {
  guardrail_arn = aws_bedrock_guardrail.preflight.guardrail_arn
  description   = "Initial lab version"
}

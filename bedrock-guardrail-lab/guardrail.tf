resource "aws_bedrock_guardrail" "this" {
  name                      = "${var.project_name}-guardrail"
  description               = "Demo guardrail for claims correspondence drafting"
  blocked_input_messaging   = "This request cannot be processed due to policy restrictions."
  blocked_outputs_messaging = "The generated response was withheld due to policy restrictions."

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
  }

  # Anonymizes PII in model output so raw values never leave the guardrail boundary.
  sensitive_information_policy_config {
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "PHONE"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
  }

  # A deterministic custom word lets you trigger an intervention on demand for testing,
  # instead of relying on the model to say something unsafe by chance.
  word_policy_config {
    words_config {
      text = "TESTVIOLATION"
    }
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }
}

resource "aws_bedrock_guardrail_version" "this" {
  guardrail_arn = aws_bedrock_guardrail.this.guardrail_arn
  description   = "Initial lab version"
}

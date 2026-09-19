# NOTE: aws_bedrockagent_prompt manages the DRAFT prompt via hashicorp/aws.
# Creating an immutable version (CreatePromptVersion) has no equivalent in
# that provider, so awscc_bedrock_prompt_version (Cloud Control) is used for
# that resource below - see the comment there.

resource "aws_bedrockagent_prompt" "adverse_event_summary" {
  name             = "adverse-event-summary"
  description      = "Summarizes an adverse event narrative into structured pharmacovigilance sections."
  default_variant  = "production"

  variant {
    name          = "production"
    template_type = "TEXT"
    model_id      = var.model_id

    template_configuration {
      text {
        text = file("${path.module}/source_prompts/adverse_event_summary_v1.txt")

        input_variable {
          name = "narrative_text"
        }
      }
    }

    inference_configuration {
      text {
        max_tokens  = 1024
        temperature = 0.2
      }
    }
  }
}

# A version is an immutable, point-in-time snapshot of the prompt's current
# draft - this is the production governance artifact, NOT the console's
# "Save as draft" action (which replaces the draft and discards other
# compared variants rather than preserving history).
#
# hashicorp/aws has no resource for this (no aws_bedrockagent_prompt_version,
# no create_version argument on aws_bedrockagent_prompt) - CreatePromptVersion
# is only reachable via the awscc (Cloud Control) provider today.
resource "awscc_bedrock_prompt_version" "initial_release" {
  prompt_arn  = aws_bedrockagent_prompt.adverse_event_summary.arn
  description = "Initial approved release. Change ticket CM-1001."
}

# claude-3-5-haiku-20241022-v1:0 (baked into initial_release above) reached
# end-of-life on Bedrock. This snapshot captures the draft after model_id was
# migrated to var.model_id's new value - the prior version is left in place
# as history, matching the lab's point-in-time-snapshot governance model.
resource "awscc_bedrock_prompt_version" "model_migration_release" {
  prompt_arn  = aws_bedrockagent_prompt.adverse_event_summary.arn
  description = "Model migration off EOL claude-3-5-haiku. Change ticket CM-1003."

  depends_on = [aws_bedrockagent_prompt.adverse_event_summary]
}

# model_migration_release (above) baked in the bare
# anthropic.claude-haiku-4-5-... model ID, which turned out to require
# on-demand throughput Bedrock doesn't offer for that model - the draft was
# corrected to the us.anthropic.claude-haiku-4-5-... cross-region inference
# profile ID, so this snapshot captures that corrected draft.
resource "awscc_bedrock_prompt_version" "inference_profile_release" {
  prompt_arn  = aws_bedrockagent_prompt.adverse_event_summary.arn
  description = "Switched model_id to cross-region inference profile (on-demand not supported for this model). Change ticket CM-1004."

  depends_on = [aws_bedrockagent_prompt.adverse_event_summary]
}

# Claude Haiku 4.5 rejects requests that set both temperature and top_p -
# inference_profile_release (above) baked in both, so this snapshot captures
# the draft after top_p was dropped.
resource "awscc_bedrock_prompt_version" "inference_config_fix_release" {
  prompt_arn  = aws_bedrockagent_prompt.adverse_event_summary.arn
  description = "Removed top_p - this model only accepts one of temperature/top_p. Change ticket CM-1005."

  depends_on = [aws_bedrockagent_prompt.adverse_event_summary]
}

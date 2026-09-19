# ---------- Agent service role ----------

resource "aws_iam_role" "agent_role" {
  name = "${var.project_name}-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent/*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "agent_role_inline" {
  name = "${var.project_name}-agent-role-inline"
  role = aws_iam_role.agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeFoundationModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.foundation_model_id}"
      },
      {
        Sid      = "ReadOpenApiSchema"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.schema.arn}/${aws_s3_object.openapi_schema.key}"
      }
    ]
  })
}

# ---------- Agent ----------

resource "aws_bedrockagent_agent" "this" {
  agent_name                 = "${var.project_name}-agent"
  agent_resource_role_arn    = aws_iam_role.agent_role.arn
  foundation_model            = var.foundation_model_id
  idle_session_ttl_in_seconds = 600
  # Preparation is handled explicitly below, after the action group exists,
  # rather than relying on this flag's ordering relative to the action group.
  prepare_agent = false

  instruction = <<-EOT
    You are a scheduling assistant for a maritime terminal operator. You help
    users book container pickup appointments using the booking action
    available to you.

    Always confirm three things with the user before calling the booking
    action: the terminal ID, the appointment time (must be a specific date
    and time), and the container type. Do not guess or invent values for
    these fields.

    If the booking action returns an error, relay the specific problem to
    the user in plain language and ask them to provide a corrected value -
    do not retry with a guessed correction on their behalf.
  EOT

  depends_on = [aws_iam_role_policy.agent_role_inline]
}

# ---------- Action group: the structured tool contract ----------

resource "aws_bedrockagent_agent_action_group" "booking" {
  action_group_name          = "ContainerBookingActions"
  agent_id                   = aws_bedrockagent_agent.this.agent_id
  agent_version               = "DRAFT"
  skip_resource_in_use_check = true

  action_group_executor {
    lambda = aws_lambda_function.booking_validator.arn
  }

  api_schema {
    s3 {
      s3_bucket_name = aws_s3_bucket.schema.bucket
      s3_object_key  = aws_s3_object.openapi_schema.key
    }
  }
}

# ---------- Explicit prepare step ----------
# Bedrock agents must be "prepared" for changes (including a newly added
# action group) to take effect on the DRAFT version that InvokeAgent's
# built-in test alias (TSTALIASID) actually runs. Doing this via an explicit
# CLI call, triggered on any change to the action group, avoids depending on
# undocumented ordering behavior of the agent resource's own prepare flag.
resource "null_resource" "prepare_agent" {
  triggers = {
    action_group_id = aws_bedrockagent_agent_action_group.booking.id
    schema_hash      = filemd5("${path.module}/schema/pickup_appointments_openapi.json")
  }

  provisioner "local-exec" {
    command = "aws bedrock-agent prepare-agent --agent-id ${aws_bedrockagent_agent.this.agent_id} --region ${var.aws_region}"
  }

  depends_on = [aws_bedrockagent_agent_action_group.booking]
}

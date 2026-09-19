# Not attached to anything automatically - attach to whatever identity runs
# scripts/*.py.
resource "aws_iam_policy" "prompt_governance_lab" {
  name        = "${var.project_name}-policy"
  description = "Permissions to run the prompt-publish, invoke, and evidence-check scripts."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadReviewedSourcePrompts"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket", "s3:ListBucketVersions", "s3:GetObjectVersion"]
        Resource = [
          aws_s3_bucket.source_prompts.arn,
          "${aws_s3_bucket.source_prompts.arn}/*"
        ]
      },
      {
        Sid      = "ManagePromptDraftsAndVersions"
        Effect   = "Allow"
        Action   = ["bedrock:GetPrompt", "bedrock:UpdatePrompt", "bedrock:CreatePromptVersion", "bedrock:ListPrompts"]
        Resource = "*" # ListPrompts has no resource-level ARN; GetPrompt/UpdatePrompt/CreatePromptVersion could be scoped to the prompt ARN in production
      },
      {
        Sid      = "InvokeViaPromptArn"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:prompt/*",
          # var.model_id is a cross-region inference profile ID (e.g. "us.anthropic...") -
          # invoking it also requires InvokeModel on the underlying foundation model in
          # whichever region of the profile's geo it routes to, so that ARN is wildcarded.
          "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.model_id}",
          "arn:aws:bedrock:*::foundation-model/${replace(var.model_id, "/^[a-z]+\\./", "")}"
        ]
      },
      {
        Sid      = "ReadAuditEvidence"
        Effect   = "Allow"
        Action   = ["cloudtrail:LookupEvents", "logs:GetLogEvents", "logs:DescribeLogStreams", "logs:FilterLogEvents"]
        Resource = "*"
      }
    ]
  })
}

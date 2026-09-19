locals {
  # Cross-region inference profiles route to the underlying foundation model
  # in each region of the geo (e.g. "us."), so IAM must grant InvokeModel on
  # the profile itself AND on the foundation-model resource in every region
  # it can route to.
  bedrock_underlying_model_id = trimprefix(var.bedrock_model_id, "us.")
  bedrock_inference_regions   = ["us-east-1", "us-east-2", "us-west-2"]
}

# ---------- Lambda execution role ----------

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_inline" {
  name = "${var.project_name}-lambda-inline"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeGuardedModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ApplyGuardrail"
        ]
        Resource = concat(
          [
            "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_model_id}",
            aws_bedrock_guardrail.this.guardrail_arn
          ],
          [
            for region in local.bedrock_inference_regions :
            "arn:aws:bedrock:${region}::foundation-model/${local.bedrock_underlying_model_id}"
          ]
        )
      },
      {
        Sid      = "WriteAuditRecords"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.audit.arn}/audit/*"
      },
      {
        Sid      = "EmitViolationEvents"
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = aws_cloudwatch_event_bus.compliance.arn
      }
    ]
  })
}

# ---------- Step Functions execution role ----------

resource "aws_iam_role" "sfn_exec" {
  name = "${var.project_name}-sfn-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "sfn_inline" {
  name = "${var.project_name}-sfn-inline"
  role = aws_iam_role.sfn_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteComplianceReviewRecords"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.audit.arn}/compliance-review/*"
      },
      {
        # Required by Step Functions to deliver execution logs to CloudWatch.
        # These actions don't support resource-level permissions, so AWS
        # documents this statement with Resource = "*".
        Sid    = "AllowCloudWatchLogsDelivery"
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

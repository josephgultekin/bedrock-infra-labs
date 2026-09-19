# ---------- Preflight Lambda role ----------

resource "aws_iam_role" "preflight_exec" {
  name = "${var.project_name}-preflight-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "preflight_basic_logs" {
  role       = aws_iam_role.preflight_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "preflight_inline" {
  name = "${var.project_name}-preflight-inline"
  role = aws_iam_role.preflight_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadPhrasePolicies"
        Effect   = "Allow"
        Action   = ["dynamodb:Query"]
        Resource = aws_dynamodb_table.phrase_policies.arn
      },
      {
        Sid      = "WriteAuditMetadata"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.moderation_audit.arn
      },
      {
        Sid      = "StandaloneGuardrailCheck"
        Effect   = "Allow"
        Action   = ["bedrock:ApplyGuardrail"]
        Resource = aws_bedrock_guardrail.preflight.guardrail_arn
      },
      {
        Sid      = "InvokeResponderOnlyAfterApproval"
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.responder.arn
      }
    ]
  })
}

# ---------- Responder Lambda role ----------

resource "aws_iam_role" "responder_exec" {
  name = "${var.project_name}-responder-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "responder_basic_logs" {
  role       = aws_iam_role.responder_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "responder_inline" {
  name = "${var.project_name}-responder-inline"
  role = aws_iam_role.responder_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
      }
    ]
  })
}

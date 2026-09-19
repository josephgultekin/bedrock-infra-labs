# ---------- Lambda execution role (synchronous Detect* calls) ----------

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
        Sid      = "ReadIncomingDocuments"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.docs.arn}/incoming/*"
      },
      {
        Sid      = "WriteInsights"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.docs.arn}/insights/*"
      },
      {
        # The synchronous Detect* APIs don't support resource-level
        # permissions - they're plain inference calls, not operations on an
        # ARN-addressable resource (unlike custom classifiers/recognizers).
        Sid    = "RunComprehendDetection"
        Effect = "Allow"
        Action = [
          "comprehend:DetectDominantLanguage",
          "comprehend:DetectSentiment",
          "comprehend:DetectKeyPhrases",
          "comprehend:DetectEntities",
          "comprehend:DetectPiiEntities"
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------- Comprehend data-access role (async PII redaction job) ----------
#
# Batch jobs are a distinct IAM shape from the sync calls above: Comprehend
# itself assumes this role to read the input documents and write results,
# rather than the caller's own credentials doing the S3 I/O.

resource "aws_iam_role" "comprehend_data_access" {
  name = "${var.project_name}-comprehend-data-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "comprehend.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "comprehend_data_access_inline" {
  name = "${var.project_name}-comprehend-data-access-inline"
  role = aws_iam_role.comprehend_data_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadBatchInput"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.docs.arn}/batch-input/*"
      },
      {
        Sid      = "ListBatchInputPrefix"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.docs.arn
        Condition = {
          StringLike = { "s3:prefix" = ["batch-input/*"] }
        }
      },
      {
        Sid      = "WriteBatchOutput"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.docs.arn}/batch-output/*"
      }
    ]
  })
}

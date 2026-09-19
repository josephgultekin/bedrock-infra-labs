resource "aws_iam_role" "kb_service_role" {
  name = "${var.project_name}-kb-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "kb_service_role_inline" {
  name = "${var.project_name}-kb-service-role-inline"
  role = aws_iam_role.kb_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadSourceDocuments"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.source_docs.arn, "${aws_s3_bucket.source_docs.arn}/*"]
      },
      {
        Sid      = "InvokeEmbeddingModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
      },
      {
        # Scoped to this lab's vector bucket/index. Action set is a best
        # effort based on current S3 Vectors + Bedrock integration docs -
        # check the current IAM reference if apply/sync throws AccessDenied.
        Sid    = "ReadWriteVectorIndex"
        Effect = "Allow"
        Action = [
          "s3vectors:GetIndex",
          "s3vectors:GetVectorBucket",
          "s3vectors:PutVectors",
          "s3vectors:GetVectors",
          "s3vectors:QueryVectors",
          "s3vectors:DeleteVectors",
          "s3vectors:ListVectors"
        ]
        Resource = [
          aws_s3vectors_vector_bucket.this.vector_bucket_arn,
          aws_s3vectors_index.this.index_arn
        ]
      }
    ]
  })
}

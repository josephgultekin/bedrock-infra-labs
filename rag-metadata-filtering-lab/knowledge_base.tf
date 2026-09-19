resource "aws_bedrockagent_knowledge_base" "this" {
  name     = "${var.project_name}-kb"
  role_arn = aws_iam_role.kb_service_role.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = var.embedding_dimensions
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      vector_bucket_arn = aws_s3vectors_vector_bucket.this.vector_bucket_arn
      index_arn         = aws_s3vectors_index.this.index_arn
    }
  }

  depends_on = [aws_iam_role_policy.kb_service_role_inline]
}

resource "aws_bedrockagent_data_source" "s3" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.this.id
  name               = "${var.project_name}-s3-source"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = aws_s3_bucket.source_docs.arn
      inclusion_prefixes = ["bulletins/"]
    }
  }

  # Note: current Bedrock docs do not expose a request field literally named
  # `metadataFilesPrefix` on the S3 data source config (only bucket_arn and
  # inclusion_prefixes are documented). The metadata mechanism itself - a
  # co-located <file>.metadata.json sidecar per document - is real and is
  # exactly what s3_source.tf creates; the exam's parameter name appears to
  # be exam-specific terminology rather than a literal current API field.
}

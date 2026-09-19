resource "aws_s3vectors_vector_bucket" "this" {
  vector_bucket_name = "${var.project_name}-vectors"
}

resource "aws_s3vectors_index" "this" {
  index_name         = "${var.project_name}-index"
  vector_bucket_name = aws_s3vectors_vector_bucket.this.vector_bucket_name
  data_type          = "float32"
  dimension          = var.embedding_dimensions
  distance_metric    = "cosine"

  # Real gotcha: Bedrock's internal chunk-text and metadata-blob keys are
  # filterable by default, which routinely blows past S3 Vectors' 2 KB
  # filterable-metadata-per-vector limit and throws ValidationException
  # during ingestion. Marking them non-filterable fixes it and costs nothing,
  # since we never need to *filter* on document text anyway.
  metadata_configuration {
    non_filterable_metadata_keys = [
      "AMAZON_BEDROCK_TEXT",
      "AMAZON_BEDROCK_METADATA",
    ]
  }
}

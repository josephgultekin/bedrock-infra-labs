resource "aws_s3_bucket" "schema" {
  bucket        = "${var.project_name}-schema-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "schema" {
  bucket                  = aws_s3_bucket.schema.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "openapi_schema" {
  bucket       = aws_s3_bucket.schema.id
  key          = "schema/pickup_appointments_openapi.json"
  source       = "${path.module}/schema/pickup_appointments_openapi.json"
  etag         = filemd5("${path.module}/schema/pickup_appointments_openapi.json")
  content_type = "application/json"
}

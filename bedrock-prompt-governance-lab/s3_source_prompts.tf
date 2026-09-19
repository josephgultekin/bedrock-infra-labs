resource "aws_s3_bucket" "source_prompts" {
  bucket        = "${var.project_name}-source-prompts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "source_prompts" {
  bucket = aws_s3_bucket.source_prompts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "source_prompts" {
  bucket                  = aws_s3_bucket.source_prompts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "source_prompts" {
  bucket = aws_s3_bucket.source_prompts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# The initial reviewed template. Every subsequent approved edit is a new
# object PUT, which S3 Versioning retains automatically - this is the
# "reviewed prompt source files" requirement, independent of anything in
# Bedrock Prompt Management.
resource "aws_s3_object" "adverse_event_summary_v1" {
  bucket       = aws_s3_bucket.source_prompts.id
  key          = "adverse_event_summary.txt"
  source       = "${path.module}/source_prompts/adverse_event_summary_v1.txt"
  etag         = filemd5("${path.module}/source_prompts/adverse_event_summary_v1.txt")
  content_type = "text/plain"

  # Stands in for a change-management ticket reference - in a real pipeline
  # this would be set by whatever tool enforces the approval step.
  metadata = {
    "change-ticket" = "CM-1001"
    "approved-by"   = "pharmacovigilance-governance-team"
  }
}

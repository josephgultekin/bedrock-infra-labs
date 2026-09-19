resource "aws_s3_bucket" "source_data" {
  bucket        = "${var.project_name}-source-data-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "source_data" {
  bucket                  = aws_s3_bucket.source_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "source_data" {
  bucket = aws_s3_bucket.source_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Small sample dataset standing in for the vessel maintenance incident logs
# that a RAG-backed summarizer would draw on. Glue crawls this to produce
# the data-provenance side of the evidence framework.
resource "aws_s3_object" "sample_incidents" {
  bucket       = aws_s3_bucket.source_data.id
  key          = "incidents/sample_incidents.csv"
  content_type = "text/csv"
  content      = <<-CSV
    incident_id,vessel_id,incident_date,description,resolution
    INC-1001,VSL-204,2026-03-11,Main engine coolant leak detected during routine inspection,Replaced coolant hose and pressure-tested system
    INC-1002,VSL-118,2026-04-02,Bilge pump failure in engine room during heavy seas,Replaced pump motor and verified backup pump operational
    INC-1003,VSL-204,2026-05-19,Navigation radar intermittent signal loss,Reseted antenna connection and updated firmware
  CSV
}

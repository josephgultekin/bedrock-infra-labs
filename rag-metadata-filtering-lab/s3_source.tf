resource "aws_s3_bucket" "source_docs" {
  bucket        = "${var.project_name}-source-docs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "source_docs" {
  bucket                  = aws_s3_bucket.source_docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "source_docs" {
  bucket = aws_s3_bucket.source_docs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

locals {
  bulletins = {
    "tractor-hydraulic-2026" = {
      product_family  = "Tractors"
      authoring_team  = "Powertrain"
      effective_date  = 20260115 # YYYYMMDD as NUMBER, not a string - required for >= / <= filtering
      body            = "Service Bulletin: Tractor hydraulic system pressure recalibration. Applies to all Tractors product family units manufactured after 2022. Fleet operators should schedule hydraulic pressure recalibration during the next scheduled maintenance window to prevent premature seal wear."
    }
    "combine-sensor-2026" = {
      product_family = "Combines"
      authoring_team = "Electronics"
      effective_date = 20260601
      body           = "Service Bulletin: Combine harvester grain-loss sensor firmware update. Applies to Combines product family units with the Gen3 sensor array. Update firmware to version 4.2.1 to correct intermittent sensor dropout during high-throughput harvesting."
    }
    "tractor-brake-2025" = {
      product_family = "Tractors"
      authoring_team = "Chassis"
      effective_date = 20250310 # deliberately older, to be excluded by an effective-timestamp filter
      body           = "Service Bulletin: Tractor parking brake cable tension inspection. Applies to Tractors product family units. This bulletin has been superseded by later chassis guidance but is retained for historical reference."
    }
    "sprayer-nozzle-2026" = {
      product_family = "Sprayers"
      authoring_team = "Powertrain"
      effective_date = 20260320 # deliberately a different product family, to be excluded by a product-family filter
      body           = "Service Bulletin: Sprayer nozzle clogging under high-viscosity chemical loads. Applies to Sprayers product family units. Recommend flushing the nozzle assembly with the updated cleaning solvent after each high-viscosity application."
    }
  }
}

resource "aws_s3_object" "bulletin_text" {
  for_each     = local.bulletins
  bucket       = aws_s3_bucket.source_docs.id
  key          = "bulletins/${each.key}.txt"
  content      = each.value.body
  content_type = "text/plain"
}

# The managed metadata mechanism for an S3 data source: a sidecar file named
# <source-file>.metadata.json, stored alongside the source file. Bedrock infers
# the attribute type (STRING/NUMBER/BOOLEAN) from the JSON value's own type -
# no explicit type wrapper is required in the current schema.
resource "aws_s3_object" "bulletin_metadata" {
  for_each     = local.bulletins
  bucket       = aws_s3_bucket.source_docs.id
  key          = "bulletins/${each.key}.txt.metadata.json"
  content_type = "application/json"
  content = jsonencode({
    metadataAttributes = {
      product_family = each.value.product_family
      authoring_team = each.value.authoring_team
      effective_date = each.value.effective_date
    }
  })
}

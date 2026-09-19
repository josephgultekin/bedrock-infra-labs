# Per-school prohibited phrase list. PAY_PER_REQUEST -> no idle/provisioned cost.
resource "aws_dynamodb_table" "phrase_policies" {
  name         = "${var.project_name}-phrase-policies"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "school_id"
  range_key    = "phrase"

  attribute {
    name = "school_id"
    type = "S"
  }

  attribute {
    name = "phrase"
    type = "S"
  }
}

# One demo phrase so BLOCKED_PHRASE is reproducible without manual data entry.
resource "aws_dynamodb_table_item" "demo_phrase" {
  table_name = aws_dynamodb_table.phrase_policies.name
  hash_key   = aws_dynamodb_table.phrase_policies.hash_key
  range_key  = aws_dynamodb_table.phrase_policies.range_key

  item = jsonencode({
    school_id = { S = var.demo_school_id }
    phrase    = { S = "banned_topic_xyz" }
  })
}

# Decision metadata only - never the rejected prompt text itself.
resource "aws_dynamodb_table" "moderation_audit" {
  name         = "${var.project_name}-moderation-audit"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }
}

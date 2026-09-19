resource "aws_cloudwatch_log_group" "sfn" {
  name              = "/aws/vendedlogs/states/${var.project_name}-compliance"
  retention_in_days = 7
}

resource "aws_sfn_state_machine" "compliance_review" {
  name     = "${var.project_name}-compliance-review"
  role_arn = aws_iam_role.sfn_exec.arn
  type     = "EXPRESS" # short-lived, per-event workflow -> pay per request/duration, cheapest fit

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  # Demo workflow: files the flagged, already-redacted record into a
  # "compliance-review" prefix for a human reviewer to pick up.
  # A real workflow would add a human-approval step (e.g. SNS + wait-for-callback)
  # here instead of finishing immediately.
  definition = jsonencode({
    Comment = "Routes guardrail-flagged interactions to a compliance review queue"
    StartAt = "FileForReview"
    States = {
      FileForReview = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:s3:putObject"
        Parameters = {
          "Bucket"      = aws_s3_bucket.audit.bucket
          "Key.$"       = "States.Format('compliance-review/{}.json', $$.Execution.Name)"
          "Body.$"      = "$"
          "ContentType" = "application/json"
        }
        End = true
      }
    }
  })
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "TimeToFirstToken (streaming calls only - p50/p90)"
          region = var.aws_region
          period = 300
          metrics = [
            ["AWS/Bedrock", "TimeToFirstToken", "ModelId", var.model_id, { "stat" = "p50", "label" = "p50" }],
            ["AWS/Bedrock", "TimeToFirstToken", "ModelId", var.model_id, { "stat" = "p90", "label" = "p90" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          # Deliberately labeled: this metric has no Operation dimension, so
          # it reflects BOTH streaming and non-streaming calls to this model
          # combined - see README for what that means for reading this widget.
          title  = "InvocationLatency - total duration (streaming + non-streaming combined, p50/p90)"
          region = var.aws_region
          period = 300
          metrics = [
            ["AWS/Bedrock", "InvocationLatency", "ModelId", var.model_id, { "stat" = "p50", "label" = "p50" }],
            ["AWS/Bedrock", "InvocationLatency", "ModelId", var.model_id, { "stat" = "p90", "label" = "p90" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Invocations (SampleCount) - all API operations combined"
          region = var.aws_region
          period = 300
          metrics = [
            ["AWS/Bedrock", "Invocations", "ModelId", var.model_id, { "stat" = "SampleCount", "label" = "Invocations" }],
            ["AWS/Bedrock", "TimeToFirstToken", "ModelId", var.model_id, { "stat" = "SampleCount", "label" = "TimeToFirstToken samples (streaming calls only)" }]
          ]
        }
      }
    ]
  })
}

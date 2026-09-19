resource "aws_sns_topic" "latency_alerts" {
  name = "${var.project_name}-latency-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.latency_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Instruments the initial visible delay - the "operators retry because the
# page is blank" problem from the scenario.
resource "aws_cloudwatch_metric_alarm" "ttft_high" {
  alarm_name          = "${var.project_name}-ttft-p90-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 3
  metric_name         = "TimeToFirstToken"
  namespace           = "AWS/Bedrock"
  period              = 300
  extended_statistic  = "p90"
  threshold           = var.ttft_alarm_threshold_ms
  treat_missing_data  = "notBreaching"
  alarm_description = "p90 time-to-first-token for streaming rebooking-guidance calls is elevated - the blank-screen delay operators complained about may be creeping back even with streaming enabled."

  dimensions = {
    ModelId = var.model_id
  }

  alarm_actions = [aws_sns_topic.latency_alerts.arn]
}

# Instruments total generation duration - separate from the above, since a
# request can have a fast first token but still run long overall.
resource "aws_cloudwatch_metric_alarm" "total_latency_high" {
  alarm_name          = "${var.project_name}-invocation-latency-p90-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 3
  metric_name         = "InvocationLatency"
  namespace           = "AWS/Bedrock"
  period              = 300
  extended_statistic  = "p90"
  threshold           = var.total_latency_alarm_threshold_ms
  treat_missing_data  = "notBreaching"
  alarm_description = "p90 total generation duration for rebooking-guidance calls is elevated. Reflects streaming and non-streaming calls combined - there is no Operation dimension on this metric."

  dimensions = {
    ModelId = var.model_id
  }

  alarm_actions = [aws_sns_topic.latency_alerts.arn]
}

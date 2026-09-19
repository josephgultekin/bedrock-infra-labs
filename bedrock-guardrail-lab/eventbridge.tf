resource "aws_cloudwatch_event_bus" "compliance" {
  name = "${var.project_name}-compliance-bus"
}

resource "aws_cloudwatch_event_rule" "violation" {
  name           = "${var.project_name}-route-violations"
  event_bus_name = aws_cloudwatch_event_bus.compliance.name

  event_pattern = jsonencode({
    source      = ["claims.guardrail"]
    detail-type = ["GuardrailViolation"]
  })
}

resource "aws_iam_role" "eventbridge_invoke_sfn" {
  name = "${var.project_name}-eventbridge-to-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_invoke_sfn" {
  name = "${var.project_name}-eventbridge-to-sfn"
  role = aws_iam_role.eventbridge_invoke_sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = aws_sfn_state_machine.compliance_review.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "sfn" {
  event_bus_name = aws_cloudwatch_event_bus.compliance.name
  rule           = aws_cloudwatch_event_rule.violation.name
  arn            = aws_sfn_state_machine.compliance_review.arn
  role_arn       = aws_iam_role.eventbridge_invoke_sfn.arn
}

# Operational audit trail: individual runtime decisions (e.g. "a summary was
# generated for incident X, tied to model card version Y") land here. This is
# deliberately separate from the Model Card, which holds governance evidence
# about the model itself rather than a log of individual invocations.
resource "aws_cloudwatch_log_group" "runtime_events" {
  name              = "/governance/${var.project_name}/runtime-decision-events"
  retention_in_days = 30
}

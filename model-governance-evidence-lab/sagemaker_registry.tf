# A real Model Package Group and Model Package, registered as metadata only.
# Nothing here is ever trained, hosted, or invoked, so it carries no compute cost -
# this purely exercises the Model Registry side of the governance evidence flow
# that the Model Card pipeline (see scripts/governance_pipeline.py) reads from.
#
# The AWS provider has no aws_sagemaker_model_package resource (only the group
# is supported there), so the model package itself is created via the Cloud
# Control API through the awscc provider.

resource "aws_sagemaker_model_package_group" "this" {
  model_package_group_name        = "${var.project_name}-model-group"
  model_package_group_description = "Vessel maintenance incident summarization models"
}

resource "awscc_sagemaker_model_package" "this" {
  model_package_group_name = aws_sagemaker_model_package_group.this.model_package_group_name
  model_approval_status    = "PendingManualApproval"

  inference_specification = {
    containers = [
      {
        image = var.placeholder_container_image
      }
    ]
    supported_content_types       = ["text/csv"]
    supported_response_mime_types = ["text/csv"]
  }
}

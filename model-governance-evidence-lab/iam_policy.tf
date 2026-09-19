# This policy is intentionally not attached to anything automatically - it's
# the permission set a real CI/CD pipeline role would need. Attach it to your
# own user/role (or a dedicated pipeline role) before running the scripts.
resource "aws_iam_policy" "governance_pipeline" {
  name        = "${var.project_name}-governance-pipeline-policy"
  description = "Permissions needed to run the governance pipeline scripts in scripts/."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ModelCardLifecycle"
        Effect = "Allow"
        Action = [
          "sagemaker:CreateModelCard",
          "sagemaker:UpdateModelCard",
          "sagemaker:DescribeModelCard",
          "sagemaker:ListModelCardVersions",
          "sagemaker:DeleteModelCard"
        ]
        Resource = "arn:aws:sagemaker:${var.aws_region}:${data.aws_caller_identity.current.account_id}:model-card/*"
      },
      {
        Sid      = "ModelRegistryReadAndApprove"
        Effect   = "Allow"
        Action   = ["sagemaker:DescribeModelPackage", "sagemaker:UpdateModelPackage"]
        Resource = awscc_sagemaker_model_package.this.model_package_arn
      },
      {
        Sid    = "GlueCrawlerOperate"
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:GetTable",
          "glue:GetTables"
        ]
        # Glue crawler/table read actions don't take fine-grained resource ARNs
        # in this policy shape; scope further with catalog/database conditions
        # if you productionize this.
        Resource = "*"
      },
      {
        Sid      = "RuntimeEventLogging"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
        Resource = "${aws_cloudwatch_log_group.runtime_events.arn}:*"
      }
    ]
  })
}

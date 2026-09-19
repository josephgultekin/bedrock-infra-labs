resource "aws_glue_catalog_database" "this" {
  name = replace("${var.project_name}_db", "-", "_")
}

resource "aws_iam_role" "glue_crawler" {
  name = "${var.project_name}-glue-crawler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3_read" {
  name = "${var.project_name}-glue-s3-read"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.source_data.arn,
        "${aws_s3_bucket.source_data.arn}/*"
      ]
    }]
  })
}

# No schedule attached - this crawler only runs (and only costs anything)
# when you explicitly start it.
resource "aws_glue_crawler" "incidents" {
  name          = "${var.project_name}-incident-crawler"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.this.name

  s3_target {
    path = "s3://${aws_s3_bucket.source_data.bucket}/incidents/"
  }

  depends_on = [aws_s3_object.sample_incidents]
}

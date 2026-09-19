variable "aws_region" {
  description = "Region. S3 Vectors + Bedrock Knowledge Bases availability varies - us-east-1 and us-west-2 are safe defaults."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names."
  type        = string
  default     = "agri-kb-metadata-lab"
}

variable "embedding_dimensions" {
  description = "Output dimension for Titan Embed Text v2. Must match the vector index dimension."
  type        = number
  default     = 1024
}

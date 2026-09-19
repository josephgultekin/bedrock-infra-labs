output "knowledge_base_id" {
  value = aws_bedrockagent_knowledge_base.this.id
}

output "data_source_id" {
  value = aws_bedrockagent_data_source.s3.data_source_id
}

output "source_bucket" {
  value = aws_s3_bucket.source_docs.bucket
}

output "vector_bucket_name" {
  value = aws_s3vectors_vector_bucket.this.vector_bucket_name
}

output "vector_index_name" {
  value = aws_s3vectors_index.this.index_name
}

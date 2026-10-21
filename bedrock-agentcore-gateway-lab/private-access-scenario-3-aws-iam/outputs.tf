output "vpc_id" {
  value = aws_vpc.this.id
}

output "nat_instance_public_ip" {
  value = aws_eip.nat.public_ip
}

output "bastion_instance_id" {
  description = "Target for: aws ssm start-session --target <this> --profile dops"
  value       = aws_instance.bastion.id
}

output "vpc_endpoint_id" {
  value = aws_vpc_endpoint.gateway.id
}

output "gateway_id" {
  value = aws_bedrockagentcore_gateway.tools.gateway_id
}

output "gateway_arn" {
  value = aws_bedrockagentcore_gateway.tools.gateway_arn
}

output "gateway_url" {
  value = aws_bedrockagentcore_gateway.tools.gateway_url
}

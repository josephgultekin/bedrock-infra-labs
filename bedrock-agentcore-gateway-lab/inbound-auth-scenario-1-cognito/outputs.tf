output "vpc_id" {
  value = aws_vpc.this.id
}

output "nat_instance_public_ip" {
  value = aws_eip.nat.public_ip
}

output "user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "token_endpoint" {
  description = "POST client_credentials grant here to get a JWT."
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/token"
}

output "resource_server_identifier" {
  value = aws_cognito_resource_server.tools.identifier
}

output "app_client_id" {
  value = aws_cognito_user_pool_client.gateway_client.id
}

output "app_client_secret" {
  sensitive = true
  value     = aws_cognito_user_pool_client.gateway_client.client_secret
}

output "discovery_url" {
  value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.this.id}/.well-known/openid-configuration"
}

output "gateway_id" {
  value = aws_bedrockagentcore_gateway.tools.gateway_id
}

output "gateway_url" {
  value = aws_bedrockagentcore_gateway.tools.gateway_url
}

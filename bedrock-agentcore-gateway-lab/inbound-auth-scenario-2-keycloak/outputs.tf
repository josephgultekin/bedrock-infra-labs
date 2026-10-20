output "vpc_id" {
  value = aws_vpc.this.id
}

output "nat_instance_public_ip" {
  value = aws_eip.nat.public_ip
}

output "ecr_repository_url" {
  description = "Mirror the public Keycloak image here before the first apply - see README step 1."
  value       = aws_ecr_repository.keycloak.repository_url
}

output "keycloak_url" {
  value = "https://${aws_apprunner_service.keycloak.service_url}"
}

output "token_endpoint" {
  description = "POST client_credentials grant here to get a JWT."
  value       = "https://${aws_apprunner_service.keycloak.service_url}/realms/${var.keycloak_realm_name}/protocol/openid-connect/token"
}

output "discovery_url" {
  value = "https://${aws_apprunner_service.keycloak.service_url}/realms/${var.keycloak_realm_name}/.well-known/openid-configuration"
}

output "client_id" {
  value = keycloak_openid_client.gateway_client.client_id
}

output "client_secret" {
  sensitive = true
  value     = keycloak_openid_client.gateway_client.client_secret
}

output "gateway_id" {
  value = aws_bedrockagentcore_gateway.tools.gateway_id
}

output "gateway_url" {
  value = aws_bedrockagentcore_gateway.tools.gateway_url
}

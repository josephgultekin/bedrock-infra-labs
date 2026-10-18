output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_instance_public_ip" {
  description = "Useful for an SSM Session Manager check-in: aws ssm start-session --target <instance-id>."
  value       = aws_eip.nat.public_ip
}

output "ecr_repository_url" {
  description = "Push the agent image here, e.g. docker push <this>:<tag>."
  value       = aws_ecr_repository.agent.repository_url
}

output "gateway_id" {
  value = aws_bedrockagentcore_gateway.tools.gateway_id
}

output "gateway_arn" {
  value = aws_bedrockagentcore_gateway.tools.gateway_arn
}

output "gateway_url" {
  description = "The Gateway's real MCP endpoint - used directly by scripts/invoke_gateway_tool.py."
  value       = aws_bedrockagentcore_gateway.tools.gateway_url
}

output "agent_runtime_id" {
  value = aws_bedrockagentcore_agent_runtime.agent.agent_runtime_id
}

output "agent_runtime_arn" {
  value = aws_bedrockagentcore_agent_runtime.agent.agent_runtime_arn
}

output "github_actions_role_arn" {
  description = "Set as the AWS_ROLE_ARN repo variable/secret for the build-push-agentcore-image workflow."
  value       = aws_iam_role.github_actions_deploy.arn
}

output "workload_identity_arn" {
  value = aws_bedrockagentcore_workload_identity.agent.workload_identity_arn
}

output "api_key_credential_provider_arn" {
  value = aws_bedrockagentcore_api_key_credential_provider.sample_tool.credential_provider_arn
}

output "policy_engine_arn" {
  value = aws_bedrockagentcore_policy_engine.this.policy_engine_arn
}

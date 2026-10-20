terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # AgentCore resources (aws_bedrockagentcore_*) landed in 6.17.0.
      version = "~> 6.17"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    keycloak = {
      source = "keycloak/keycloak"
      # Confirmed available on OpenTofu's registry during planning (v5.10.0
      # installed cleanly from a scratch `tofu init`).
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Authenticates against Keycloak's bootstrap admin user (KEYCLOAK_ADMIN /
# KEYCLOAK_ADMIN_PASSWORD env vars set on the App Runner service in
# apprunner.tf) in the default "master" realm. This provider can only be
# configured once the App Runner service is up and serving - see README's
# two-phase apply.
provider "keycloak" {
  client_id     = "admin-cli"
  url           = "https://${aws_apprunner_service.keycloak.service_url}"
  username      = var.keycloak_admin_username
  password      = var.keycloak_admin_password
  initial_login = false # defer login until a keycloak_* resource actually needs it, not during provider configure
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

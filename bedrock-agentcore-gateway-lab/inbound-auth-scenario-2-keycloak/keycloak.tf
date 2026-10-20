# Configured via the keycloak Terraform provider (versions.tf), which talks
# to Keycloak's own admin REST API - a different system from AWS's API, so
# `tofu plan`/`apply` against these two resources needs the App Runner
# service already up and healthy. See README's three-phase apply.

locals {
  # A plain, predictable string rather than reading keycloak_openid_client's
  # client_id back out - lets gateway.tf reference it without creating a
  # graph dependency on the keycloak provider, which matters for the
  # -target'ed phases of the apply (see README).
  gateway_client_id = "${var.project_name}-gateway-client"
}

resource "keycloak_realm" "this" {
  realm   = var.keycloak_realm_name
  enabled = true
}

resource "keycloak_openid_client" "gateway_client" {
  realm_id  = keycloak_realm.this.id
  client_id = local.gateway_client_id
  name      = "AgentCore Gateway client"

  access_type                  = "CONFIDENTIAL"
  service_accounts_enabled     = true # client_credentials grant - no human user in this lab
  standard_flow_enabled        = false
  direct_access_grants_enabled = false
}

# Mirrors the AWS console's Gateway creation screen's "Quick create
# configurations with Cognito" path: a User Pool, a prefix domain (so there's
# a token endpoint without needing an ACM cert), a Resource Server defining
# one custom scope, and a confidential app client using the
# client_credentials grant (machine-to-machine - there's no human user in
# this lab, just a script acting as the "agent" calling the Gateway).

resource "aws_cognito_user_pool" "this" {
  name = "${var.project_name}-pool"
}

locals {
  # Cognito rejects any domain prefix containing the literal word "cognito"
  # (InvalidParameterException: "Domain cannot contain reserved word:
  # cognito") - var.project_name's default ("agentcore-gw-cognito")
  # contains it, so swap it out just for the domain prefix.
  cognito_domain_prefix = replace(var.project_name, "cognito", "auth")
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "${local.cognito_domain_prefix}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_resource_server" "tools" {
  identifier   = "${var.project_name}-tools"
  name         = "Gateway tools"
  user_pool_id = aws_cognito_user_pool.this.id

  scope {
    scope_name        = "invoke"
    scope_description = "Invoke the Gateway's MCP tools"
  }
}

resource "aws_cognito_user_pool_client" "gateway_client" {
  name         = "${var.project_name}-gateway-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret                      = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["${aws_cognito_resource_server.tools.identifier}/invoke"]
  supported_identity_providers         = ["COGNITO"]
}

# Hosts Keycloak as a public HTTPS service via App Runner - no ALB/ACM/
# Route53 needed, App Runner's auto-assigned *.awsapprunner.com domain
# already terminates HTTPS. start-dev mode with embedded H2 storage: no RDS,
# but data is EPHEMERAL - a container restart/redeploy loses every realm
# and client Terraform created below. Fine for a throwaway lab, called out
# clearly in README.
#
# NOTE (unverified - see README): the exact KC_* env vars Keycloak needs to
# behave correctly behind App Runner's own TLS termination (effectively a
# reverse proxy) weren't confirmed against a live deployment. KC_HOSTNAME
# cannot be set to the App Runner URL at creation time (chicken-and-egg -
# the URL doesn't exist until the service is created), hence
# KC_HOSTNAME_STRICT = "false" below as a workaround to avoid Keycloak
# rejecting requests over hostname mismatch; double-check this is still
# correct for whatever Keycloak version you pull.

resource "aws_iam_role" "apprunner_ecr_access" {
  name = "${var.project_name}-apprunner-ecr-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "build.apprunner.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_access" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# The admin password is injected via runtime_environment_secrets (SSM
# SecureString), not a plain env var, so it doesn't sit in cleartext in the
# App Runner console or in this lab's plan/state output - though it IS
# still in Terraform state as the SSM parameter's value, same as any
# Terraform-managed secret.
resource "aws_ssm_parameter" "keycloak_admin_password" {
  name  = "/${var.project_name}/keycloak-admin-password"
  type  = "SecureString"
  value = var.keycloak_admin_password
}

data "aws_kms_alias" "ssm" {
  name = "alias/aws/ssm"
}

resource "aws_iam_role" "apprunner_instance" {
  name = "${var.project_name}-apprunner-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "tasks.apprunner.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "apprunner_instance_read_admin_password" {
  name = "${var.project_name}-apprunner-read-admin-password"
  role = aws_iam_role.apprunner_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadAdminPasswordParameter"
        Effect   = "Allow"
        Action   = ["ssm:GetParameters"]
        Resource = aws_ssm_parameter.keycloak_admin_password.arn
      },
      {
        Sid      = "DecryptWithDefaultSsmKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = data.aws_kms_alias.ssm.target_key_arn
      },
    ]
  })
}

resource "aws_apprunner_service" "keycloak" {
  service_name = "${var.project_name}-keycloak"

  source_configuration {
    auto_deployments_enabled = false # predictable for a lab - redeploy explicitly, not on every ECR push

    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }

    image_repository {
      image_identifier      = "${aws_ecr_repository.keycloak.repository_url}:${var.keycloak_image_tag}"
      image_repository_type = "ECR"

      image_configuration {
        port          = "8080"
        start_command = "start-dev"
        runtime_environment_variables = {
          KEYCLOAK_ADMIN           = var.keycloak_admin_username
          KC_HTTP_ENABLED          = "true"
          KC_HOSTNAME_STRICT       = "false"
          KC_HOSTNAME_STRICT_HTTPS = "false"
        }
        runtime_environment_secrets = {
          KEYCLOAK_ADMIN_PASSWORD = aws_ssm_parameter.keycloak_admin_password.arn
        }
      }
    }
  }

  instance_configuration {
    cpu               = "1024" # Keycloak (Quarkus/JVM) wants more than App Runner's smallest size
    memory            = "2048"
    instance_role_arn = aws_iam_role.apprunner_instance.arn
  }

  network_configuration {
    ingress_configuration {
      is_publicly_accessible = true
    }
  }

  tags = {
    Name = "${var.project_name}-keycloak"
  }
}

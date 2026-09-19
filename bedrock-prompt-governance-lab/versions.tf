terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # aws_bedrockagent_prompt is a recent addition - pin to a version
      # known to include it.
      version = "~> 6.34"
    }
    # hashicorp/aws has no resource for the CreatePromptVersion API (there is
    # no "create_version" argument on aws_bedrockagent_prompt either) - the
    # awscc (Cloud Control) provider fills the gap via awscc_bedrock_prompt_version,
    # which wraps the AWS::Bedrock::PromptVersion CloudFormation resource type.
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "awscc" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }

  # NOTE (dev -> prod migration): local state is fine for this temporary dev
  # environment. When this is lifted into Publicis's production Terraform,
  # replace this with whatever remote backend (S3 + DynamoDB lock table, or
  # Terraform Cloud) the production stack already uses, and move the
  # workspace/account IDs below into that stack's tfvars conventions instead
  # of this file.
  # backend "s3" {}
}

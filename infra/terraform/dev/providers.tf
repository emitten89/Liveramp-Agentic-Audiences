provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Workspace-level auth: expects DATABRICKS_HOST / DATABRICKS_TOKEN (or a
# .databrickscfg profile) in the environment running Terraform. Do NOT hardcode
# a token here or in tfvars.
provider "databricks" {
  host = var.databricks_workspace_url
}

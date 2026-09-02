variable "environment" {
  description = "Environment name, used in resource naming/tagging. Keep this 'dev' for the temporary build environment."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for the dev environment's S3/IAM resources."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID that hosts the dev environment's S3 bucket and IAM role. Fill in once the AWS account exists."
  type        = string
}

variable "databricks_workspace_url" {
  description = "URL of the existing AWS Databricks workspace, e.g. https://dbc-xxxxxxxx-xxxx.cloud.databricks.com"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID (account console -> Settings). Needed only if account-level resources (metastore assignment) are managed here."
  type        = string
  default     = ""
}

# Databricks' AWS control-plane role used by Unity Catalog storage credentials
# to assume the customer-owned IAM role below. This is Databricks' published
# ARN for AWS commercial regions as of writing -- verify against
# https://docs.databricks.com/en/connect/unity-catalog/storage-credentials.html
# before applying, since Databricks occasionally rotates/adds regional ARNs.
variable "databricks_unity_catalog_role_arn" {
  description = "Databricks-owned IAM role ARN that assumes the customer storage-credential role."
  type        = string
  default     = "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYAU"
}

variable "landing_bucket_name" {
  description = "Name of the S3 bucket used as the Unity Catalog external location / landing zone for this dev environment. Must be globally unique."
  type        = string
  default     = "liveramp-agentic-audiences-dev-landing"
}

variable "catalog_name" {
  description = "Unity Catalog catalog name for this project. Mirrors the mrcl_catalog naming convention used by Publicis's production Databricks so it can be renamed/aligned on migration."
  type        = string
  default     = "liveramp_agentic_audiences"
}

variable "schema_name" {
  description = "Schema (client/project namespace) inside the catalog for this dev build."
  type        = string
  default     = "dev"
}

variable "unity_catalog_external_id" {
  description = <<-EOT
    External ID for the IAM role's trust policy condition. Leave blank for the
    first `terraform apply` (the role trusts a placeholder external ID so the
    role + storage credential can be created at all). After the first apply,
    copy the `storage_credential_external_id` output in here and re-apply to
    tighten the trust policy to the real value. See
    docs/aws-databricks-dev-setup.md for the full walkthrough.
  EOT
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags applied to all AWS resources."
  type        = map(string)
  default = {
    project     = "liveramp-agentic-audiences"
    environment = "dev"
    managed_by  = "terraform"
    temporary   = "true"
  }
}

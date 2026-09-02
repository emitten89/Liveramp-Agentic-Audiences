# IAM role that Databricks Unity Catalog assumes to read/write the landing
# bucket on behalf of the storage credential in unity_catalog.tf.
#
# This role's trust policy has a two-phase bootstrap, which is normal for
# Unity Catalog storage credentials on AWS (not a mistake in this config):
#   1. First apply: the role is created trusting the Databricks control-plane
#      role (var.databricks_unity_catalog_role_arn) with a placeholder
#      external ID, because the *real* external ID is only generated once the
#      databricks_storage_credential resource exists.
#   2. Read the `storage_credential_external_id` output, put it in
#      terraform.tfvars as `unity_catalog_external_id`, and re-apply. This
#      tightens the trust condition to the real, credential-specific value.
# Full steps: docs/aws-databricks-dev-setup.md.

data "aws_caller_identity" "current" {}

locals {
  role_name = "liveramp-agentic-audiences-${var.environment}-uc-storage"

  trust_external_id = var.unity_catalog_external_id != "" ? var.unity_catalog_external_id : "PLACEHOLDER_UNTIL_STORAGE_CREDENTIAL_EXISTS"
}

resource "aws_iam_role" "unity_catalog_storage" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DatabricksUnityCatalogAssume"
        Effect = "Allow"
        Principal = {
          AWS = var.databricks_unity_catalog_role_arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.trust_external_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "unity_catalog_storage_s3" {
  name = "${local.role_name}-s3-access"
  role = aws_iam_role.unity_catalog_storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LandingBucketReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.landing.arn,
          "${aws_s3_bucket.landing.arn}/*",
        ]
      }
    ]
  })
}

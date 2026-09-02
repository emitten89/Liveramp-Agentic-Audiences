# Unity Catalog objects for the dev environment. Naming mirrors the
# mrcl_catalog.{client}.{domain}_{entity} convention used by Publicis's
# production Databricks so this is a rename, not a redesign, when it's
# lifted into production.

resource "databricks_storage_credential" "landing" {
  name = "liveramp-agentic-audiences-${var.environment}-storage-credential"

  aws_iam_role {
    role_arn = aws_iam_role.unity_catalog_storage.arn
  }

  comment = "Storage credential for the ${var.environment} LiveRamp Agentic Audiences landing bucket."

  # Validation calls AWS to prove the role is assumable, which fails until the
  # trust policy is tightened to the real external ID (see iam.tf). Skip it
  # on the first apply; drop this once unity_catalog_external_id is set.
  skip_validation = var.unity_catalog_external_id == ""
}

resource "databricks_external_location" "landing" {
  name            = "liveramp-agentic-audiences-${var.environment}-landing"
  url             = "s3://${aws_s3_bucket.landing.bucket}/"
  credential_name = databricks_storage_credential.landing.id
  comment         = "External location backing the ${var.environment} landing zone S3 bucket."

  depends_on = [aws_iam_role_policy.unity_catalog_storage_s3]
}

resource "databricks_catalog" "this" {
  name    = var.catalog_name
  comment = "Catalog for the LiveRamp Agentic Audiences project (clean-room agentic pipelines)."

  properties = {
    purpose = "liveramp-agentic-audiences"
  }
}

resource "databricks_schema" "dev" {
  catalog_name = databricks_catalog.this.name
  name         = var.schema_name
  comment      = "Dev schema for building LiveRamp clean-room agentic audience pipelines before promotion to Publicis's production Databricks."

  properties = {
    environment = var.environment
  }
}

# Dev-only grant. Tighten to a real group/service principal (e.g.
# sp-liveramp-agentic-audiences) before this environment carries anything
# sensitive, and definitely before any production equivalent is created.
resource "databricks_grants" "schema" {
  schema = "${databricks_catalog.this.name}.${databricks_schema.dev.name}"

  grant {
    principal  = "account users"
    privileges = ["USE_SCHEMA", "USE_CATALOG", "CREATE_TABLE", "SELECT", "MODIFY"]
  }
}

# Managed volume for raw file artifacts (CSV/JSON drops) ahead of the
# bronze/silver/gold pipeline pattern in pipelines/audience/.
resource "databricks_volume" "raw_files" {
  catalog_name     = databricks_catalog.this.name
  schema_name      = databricks_schema.dev.name
  name             = "raw_files"
  volume_type      = "EXTERNAL"
  storage_location = "${databricks_external_location.landing.url}raw"
  comment          = "Raw file landing volume for ${var.environment} pipelines."
}

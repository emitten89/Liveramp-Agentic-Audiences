# Compute for the dev environment. Sized deliberately small/cheap since this
# is a temporary build environment -- bump sizing in the production Terraform
# stack, not here.

resource "databricks_sql_endpoint" "dev" {
  name                      = "liveramp-agentic-audiences-${var.environment}"
  cluster_size              = "2X-Small"
  auto_stop_mins            = 10
  min_num_clusters          = 1
  max_num_clusters          = 1
  warehouse_type            = "PRO"
  enable_serverless_compute = true

  tags {
    custom_tags {
      key   = "project"
      value = "liveramp-agentic-audiences"
    }
    custom_tags {
      key   = "environment"
      value = var.environment
    }
  }
}

resource "databricks_cluster_policy" "pipeline_dev" {
  name = "liveramp-agentic-audiences-${var.environment}-pipeline-policy"

  definition = jsonencode({
    "spark_version" = {
      type  = "fixed"
      value = "14.3.x-scala2.12"
    }
    "node_type_id" = {
      type         = "allowlist"
      values       = ["i3.xlarge", "i3.2xlarge"]
      defaultValue = "i3.xlarge"
    }
    "autotermination_minutes" = {
      type  = "fixed"
      value = 30
    }
    "custom_tags.project" = {
      type  = "fixed"
      value = "liveramp-agentic-audiences"
    }
    "custom_tags.environment" = {
      type  = "fixed"
      value = var.environment
    }
  })
}

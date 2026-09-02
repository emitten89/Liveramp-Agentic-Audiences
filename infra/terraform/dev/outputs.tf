output "landing_bucket_name" {
  value = aws_s3_bucket.landing.bucket
}

output "unity_catalog_iam_role_arn" {
  value = aws_iam_role.unity_catalog_storage.arn
}

output "storage_credential_external_id" {
  description = "Copy into unity_catalog_external_id in terraform.tfvars, then re-apply to tighten the IAM trust policy."
  value       = try(databricks_storage_credential.landing.aws_iam_role[0].external_id, null)
}

output "catalog_name" {
  value = databricks_catalog.this.name
}

output "schema_full_name" {
  value = "${databricks_catalog.this.name}.${databricks_schema.dev.name}"
}

output "raw_files_volume" {
  value = "/Volumes/${databricks_catalog.this.name}/${databricks_schema.dev.name}/raw_files"
}

output "sql_warehouse_id" {
  value = databricks_sql_endpoint.dev.id
}

output "pipeline_cluster_policy_id" {
  value = databricks_cluster_policy.pipeline_dev.id
}

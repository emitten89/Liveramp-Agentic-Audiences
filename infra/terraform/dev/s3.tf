# S3 bucket used as the Unity Catalog external location for this dev
# environment. This is the one piece of "native AWS" storage the workspace
# doesn't have yet -- everything else (compute, catalog, schema) lives inside
# Databricks and just needs this bucket + the IAM role in iam.tf to read/write it.

resource "aws_s3_bucket" "landing" {
  bucket = var.landing_bucket_name

  tags = merge(var.tags, {
    Name = var.landing_bucket_name
  })
}

resource "aws_s3_bucket_versioning" "landing" {
  bucket = aws_s3_bucket.landing.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "landing" {
  bucket                  = aws_s3_bucket.landing.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule to keep this genuinely temporary: abort incomplete multipart
# uploads and expire noncurrent versions so a "dev" bucket doesn't quietly
# accumulate cost while this environment is being built out.
resource "aws_s3_bucket_lifecycle_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

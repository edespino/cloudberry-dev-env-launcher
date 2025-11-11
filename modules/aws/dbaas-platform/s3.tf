# Random suffix for unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket for DBaaS primary storage
resource "aws_s3_bucket" "dbaas_storage" {
  bucket = "${local.storage_bucket_base}-${random_id.bucket_suffix.hex}"

  tags = merge(local.module_tags, {
    Purpose = "DBaaS Primary Storage"
  })
}

# S3 bucket for DBaaS backups
resource "aws_s3_bucket" "dbaas_backups" {
  bucket = "${local.backup_bucket_base}-${random_id.bucket_suffix.hex}"

  tags = merge(local.module_tags, {
    Purpose = "DBaaS Backup Storage"
  })
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "dbaas_storage" {
  count  = var.enable_s3_versioning ? 1 : 0
  bucket = aws_s3_bucket.dbaas_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "dbaas_backups" {
  count  = var.enable_s3_versioning ? 1 : 0
  bucket = aws_s3_bucket.dbaas_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "dbaas_storage" {
  bucket = aws_s3_bucket.dbaas_storage.id

  rule {
    id     = "development_cleanup"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = var.s3_noncurrent_version_days
    }

    expiration {
      days = var.s3_lifecycle_days
    }
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "dbaas_storage" {
  bucket = aws_s3_bucket.dbaas_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dbaas_backups" {
  bucket = aws_s3_bucket.dbaas_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "dbaas_storage" {
  bucket = aws_s3_bucket.dbaas_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "dbaas_backups" {
  bucket = aws_s3_bucket.dbaas_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

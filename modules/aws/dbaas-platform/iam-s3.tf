# IAM role for EKS to access S3 (using IRSA)
resource "aws_iam_role" "dbaas_s3_access" {
  name = "${var.env_prefix}-dbaas-s3-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.dbaas_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"
            "${replace(aws_eks_cluster.dbaas_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.module_tags, {
    Purpose = "EKS to S3 Access Role"
  })
}

resource "aws_iam_role_policy" "dbaas_s3_policy" {
  name = "${var.env_prefix}-dbaas-s3-policy"
  role = aws_iam_role.dbaas_s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.dbaas_storage.arn,
          "${aws_s3_bucket.dbaas_storage.arn}/*",
          aws_s3_bucket.dbaas_backups.arn,
          "${aws_s3_bucket.dbaas_backups.arn}/*"
        ]
      }
    ]
  })
}

# ========================================================================
# IAM User for Static Credentials (Fallback when IRSA not supported)
# ========================================================================
# NOTE: This is a workaround for applications that don't properly support
# IRSA. Create IAM user with programmatic access as a fallback option.
# Use create_iam_user=true to enable this fallback mechanism.

resource "aws_iam_user" "dbaas_s3_user" {
  count = var.create_iam_user ? 1 : 0
  name  = "${var.env_prefix}-dbaas-s3-user"

  tags = merge(local.module_tags, {
    Purpose = "DBaaS S3 Access - Static Credentials Fallback"
  })
}

resource "aws_iam_user_policy" "dbaas_s3_user_policy" {
  count = var.create_iam_user ? 1 : 0
  name  = "${var.env_prefix}-dbaas-s3-user-policy"
  user  = aws_iam_user.dbaas_s3_user[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          # Allow access to the created buckets
          aws_s3_bucket.dbaas_storage.arn,
          "${aws_s3_bucket.dbaas_storage.arn}/*",
          aws_s3_bucket.dbaas_backups.arn,
          "${aws_s3_bucket.dbaas_backups.arn}/*",
          # Allow dynamic bucket creation by the application
          "arn:aws:s3:::unionstore-bucket-*",
          "arn:aws:s3:::unionstore-bucket-*/*",
          "arn:aws:s3:::coord-bucket-*",
          "arn:aws:s3:::coord-bucket-*/*",
          "arn:aws:s3:::${var.env_prefix}-*",
          "arn:aws:s3:::${var.env_prefix}-*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "dbaas_s3_user_key" {
  count = var.create_iam_user ? 1 : 0
  user  = aws_iam_user.dbaas_s3_user[0].name
}

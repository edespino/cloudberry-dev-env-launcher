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

# IAM Resources for EC2 Cluster Discovery

# IAM Role for EC2 cluster discovery
resource "aws_iam_role" "ec2_cluster_discovery" {
  name = "${var.env_prefix}-ec2-cluster-discovery"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for EC2 describe instances
resource "aws_iam_role_policy" "ec2_describe_instances" {
  name = "${var.env_prefix}-ec2-describe-instances"
  role = aws_iam_role.ec2_cluster_discovery.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for S3 object read/write across the account (backups, wal-g
# archiving, data staging). Object-level and list actions only — no bucket
# create/delete or policy administration.
resource "aws_iam_role_policy" "s3_read_write" {
  name = "${var.env_prefix}-s3-read-write"
  role = aws_iam_role.ec2_cluster_discovery.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_cluster_discovery" {
  name = "${var.env_prefix}-ec2-cluster-discovery"
  role = aws_iam_role.ec2_cluster_discovery.name

  tags = local.common_tags
}
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

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_cluster_discovery" {
  name = "${var.env_prefix}-ec2-cluster-discovery"
  role = aws_iam_role.ec2_cluster_discovery.name

  tags = local.common_tags
}
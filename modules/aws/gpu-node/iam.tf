# SSM-only instance role. No S3, no Bedrock, no EC2 describe. SSH remains the
# daily path; SSM Session Manager is the fallback.

data "aws_partition" "current" {}

resource "aws_iam_role" "this" {
  name = "${local.name}-ssm"

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

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${local.name}-ssm"
  role = aws_iam_role.this.name

  tags = local.common_tags
}

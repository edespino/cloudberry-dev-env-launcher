# Baseline network controls for the environment VPC (network_hardening):
# - VPC flow log (all traffic) to a CloudWatch Logs group with retention
# - the VPC's default security group emptied (instances use the environment's
#   own security group)
# - the VPC's default network ACL: inbound allows everything except TCP/UDP
#   22 and 3389 from anywhere, plus ICMP; outbound allows all. In ssh access
#   mode TCP 22 is allowed from my_ip/32 only. NACLs are stateless: the
#   remaining ranges also admit return traffic to ephemeral ports. Traffic
#   between instances in the same subnet does not pass through a NACL.

locals {
  harden = var.network_hardening

  # Inbound allows from anywhere; ports 22 and 3389 left out for TCP and UDP.
  nacl_open_ranges = [
    { rule_no = 100, protocol = "tcp", from = 0, to = 21 },
    { rule_no = 110, protocol = "tcp", from = 23, to = 3388 },
    { rule_no = 120, protocol = "tcp", from = 3390, to = 65535 },
    { rule_no = 130, protocol = "udp", from = 0, to = 21 },
    { rule_no = 140, protocol = "udp", from = 23, to = 3388 },
    { rule_no = 150, protocol = "udp", from = 3390, to = 65535 },
  ]
}

# --- VPC flow log ------------------------------------------------------------

resource "aws_cloudwatch_log_group" "vpc_flow" {
  count             = local.harden ? 1 : 0
  name              = "/launcher/${var.env_prefix}/vpc-flow-logs"
  retention_in_days = var.flow_log_retention_days

  tags = local.common_tags
}

resource "aws_iam_role" "vpc_flow" {
  count = local.harden ? 1 : 0
  name  = "${var.env_prefix}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "vpc_flow" {
  count = local.harden ? 1 : 0
  name  = "${var.env_prefix}-vpc-flow-logs"
  role  = aws_iam_role.vpc_flow[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = ["${aws_cloudwatch_log_group.vpc_flow[0].arn}:*"]
    }]
  })
}

resource "aws_flow_log" "vpc" {
  count                = local.harden ? 1 : 0
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow[0].arn
  iam_role_arn         = aws_iam_role.vpc_flow[0].arn

  tags = merge(local.common_tags, {
    Name = "${var.env_prefix}-vpc-flow-log"
  })

  depends_on = [aws_iam_role_policy.vpc_flow]
}

# --- default security group: no rules ---------------------------------------

resource "aws_default_security_group" "default" {
  count  = local.harden ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.env_prefix}-default-sg-unused"
  })
}

# --- default network ACL -----------------------------------------------------

resource "aws_default_network_acl" "default" {
  count                  = local.harden ? 1 : 0
  default_network_acl_id = aws_vpc.main.default_network_acl_id

  # ssh access mode: SSH from the operator's address only (never 0.0.0.0/0)
  dynamic "ingress" {
    for_each = local.ssm_only ? [] : [1]
    content {
      rule_no    = 90
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "${var.my_ip}/32"
      from_port  = 22
      to_port    = 22
    }
  }

  dynamic "ingress" {
    for_each = local.nacl_open_ranges
    content {
      rule_no    = ingress.value.rule_no
      protocol   = ingress.value.protocol
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = ingress.value.from
      to_port    = ingress.value.to
    }
  }

  ingress {
    rule_no    = 160
    protocol   = "icmp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    icmp_type  = -1
    icmp_code  = -1
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.env_prefix}-default-nacl"
  })

  # Subnet associations stay with AWS: every subnet without an explicit ACL
  # uses the default ACL, including subnets added by the dbaas-platform module.
  lifecycle {
    ignore_changes = [subnet_ids]
  }
}

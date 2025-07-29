# VPC and Networking Resources

# Data source to get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values for AZ selection with fallback
locals {
  # Preferred AZ order: c, b, d, a (based on current spot pricing)
  preferred_azs = ["${var.region}c", "${var.region}b", "${var.region}d", "${var.region}a"]
  # Select first available AZ from our preferred list
  selected_az = element([for az in local.preferred_azs : az if contains(data.aws_availability_zones.available.names, az)], 0)
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.env_prefix}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.env_prefix}-igw"
  })
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.selected_az
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.env_prefix}-public-subnet"
  })
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.env_prefix}-public-rt"
  })
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "allow_all" {
  name_prefix = "${var.env_prefix}-allow_all"
  vpc_id      = aws_vpc.main.id

  # SSH access from user's IP (and optionally from anywhere)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allow_remote_ssh_access ? ["0.0.0.0/0"] : ["${var.my_ip}/32"]
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32", "10.0.0.0/16"]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32", "10.0.0.0/16"]
  }

  # PostgreSQL access
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32", "10.0.0.0/16"]
  }

  # Application port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32", "10.0.0.0/16"]
  }

  # Internal TCP traffic
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ICMP (ping)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.env_prefix}-sg"
  })
}

# VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.s3"

  tags = merge(local.common_tags, {
    Name = "${var.env_prefix}-s3-endpoint"
  })

}

# Placement Group for high-performance networking
resource "aws_placement_group" "cluster" {
  name     = "${var.env_prefix}-cluster-pg"
  strategy = "cluster"

  tags = merge(local.common_tags, {
    Name    = "${var.env_prefix}-cluster-placement-group"
    Purpose = "High-performance database cluster networking"
  })
}
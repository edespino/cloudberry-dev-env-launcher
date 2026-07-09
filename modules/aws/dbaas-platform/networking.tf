# Additional networking resources for EKS
data "aws_availability_zones" "available" {
  state = "available"
}

# Public subnets for internet-facing ALB (3 subnets across different AZs)
resource "aws_subnet" "eks_public" {
  count = 3

  vpc_id                  = var.vpc_id
  cidr_block              = "10.0.${count.index + 2}.0/24" # 10.0.2.0/24, 10.0.3.0/24, 10.0.4.0/24
  availability_zone       = length(var.availability_zones) > 0 ? var.availability_zones[count.index % length(var.availability_zones)] : data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.module_tags, {
    Name                     = "${var.env_prefix}-eks-public-${count.index + 1}"
    Purpose                  = "ALB and NAT Gateway"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
  })
}

# Route table for public subnets (using existing IGW from database-cluster module)
resource "aws_route_table" "eks_public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.internet_gateway_id
  }

  tags = merge(local.module_tags, {
    Name = "${var.env_prefix}-eks-public-rt"
  })
}

# Associate public subnets with public route table
resource "aws_route_table_association" "eks_public" {
  count = 3

  subnet_id      = aws_subnet.eks_public[count.index].id
  route_table_id = aws_route_table.eks_public.id
}

# Private subnets for EKS worker nodes
resource "aws_subnet" "eks_private" {
  count = 2

  vpc_id            = var.vpc_id
  cidr_block        = "10.0.${count.index + 10}.0/24" # 10.0.10.0/24, 10.0.11.0/24
  availability_zone = length(var.availability_zones) > 0 ? var.availability_zones[count.index] : data.aws_availability_zones.available.names[count.index]

  tags = merge(local.module_tags, {
    Name                              = "${var.env_prefix}-eks-private-${count.index + 1}"
    Purpose                           = "EKS Worker Nodes"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
  })
}

# NAT Gateway for private subnet internet access (use new public subnet)
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.module_tags, {
    Name = "${var.env_prefix}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.eks_public[0].id # Use first new public subnet

  tags = merge(local.module_tags, {
    Name = "${var.env_prefix}-nat-gateway"
  })

  depends_on = [
    aws_eip.nat,
    aws_subnet.eks_public
  ]
}

# Route table for private subnets
resource "aws_route_table" "eks_private" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.module_tags, {
    Name = "${var.env_prefix}-eks-private-rt"
  })
}

# Associate private subnets with route table
resource "aws_route_table_association" "eks_private" {
  count = 2

  subnet_id      = aws_subnet.eks_private[count.index].id
  route_table_id = aws_route_table.eks_private.id
}

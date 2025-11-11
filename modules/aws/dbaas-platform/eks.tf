# EKS Cluster for DBaaS services
resource "aws_eks_cluster" "dbaas_cluster" {
  name     = local.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.eks_cluster_version

  vpc_config {
    subnet_ids              = aws_subnet.eks_private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]

  tags = local.module_tags
}

# EKS Node Group
resource "aws_eks_node_group" "dbaas_workers" {
  cluster_name    = aws_eks_cluster.dbaas_cluster.name
  node_group_name = "${var.env_prefix}-dbaas-workers"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.eks_private[*].id

  instance_types = var.eks_node_instance_types
  capacity_type  = var.use_spot_instances ? "SPOT" : "ON_DEMAND"

  scaling_config {
    desired_size = var.eks_desired_capacity
    max_size     = var.eks_max_capacity
    min_size     = var.eks_min_capacity
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = local.module_tags
}

# OIDC Identity Provider for EKS
data "tls_certificate" "eks_cluster_tls" {
  url = aws_eks_cluster.dbaas_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster_tls.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.dbaas_cluster.identity[0].oidc[0].issuer

  tags = local.module_tags
}

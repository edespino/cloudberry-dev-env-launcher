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

  # Required configuration blocks for AWS EKS
  compute_config {
    enabled = false
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = false
    }
  }

  storage_config {
    block_storage {
      enabled = false
    }
  }

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
  disk_size      = var.eks_node_disk_size

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

# IAM Role for EBS CSI Driver (using IRSA)
resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "${var.env_prefix}-dbaas-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks_oidc.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.module_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver_role.name
}

# EBS CSI Driver Add-on
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.dbaas_cluster.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.37.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi_driver_role.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.module_tags
}

# Patch the gp2 storage class to make it default
resource "null_resource" "patch_gp2_default" {
  # Update kubeconfig when cluster endpoint or CA changes
  triggers = {
    cluster_endpoint = aws_eks_cluster.dbaas_cluster.endpoint
    cluster_ca       = aws_eks_cluster.dbaas_cluster.certificate_authority[0].data
    ebs_csi_version  = aws_eks_addon.ebs_csi_driver.addon_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.dbaas_cluster.name}
      kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    EOT
  }

  depends_on = [
    aws_eks_addon.ebs_csi_driver,
    aws_eks_node_group.dbaas_workers
  ]
}

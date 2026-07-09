# ============================================================================
# ALB-BASED EXTERNAL ACCESS (ACTIVE CONFIGURATION)
# ============================================================================
# This file configures external access using:
#   - AWS Load Balancer Controller (deployed via Helm)
#   - Application Load Balancer (created by controller from Ingress)
#   - Kubernetes Ingress resource
#
# This replaces the NLB-based approach due to network topology constraints.
# ============================================================================

# IAM policy for AWS Load Balancer Controller
resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = var.enable_alb_ingress ? 1 : 0

  name        = "${var.env_prefix}-alb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          "Null" = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          "Null" = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
        Condition = {
          "Null" = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          "Null" = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          "Null" = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          "Null" = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource = "*"
        Condition = {
          "Null" = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.module_tags
}

# IAM role for AWS Load Balancer Controller with OIDC
resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_alb_ingress ? 1 : 0

  name = "${var.env_prefix}-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = local.module_tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = var.enable_alb_ingress ? 1 : 0

  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
  role       = aws_iam_role.aws_load_balancer_controller[0].name
}

# Deploy AWS Load Balancer Controller via Helm
resource "null_resource" "aws_load_balancer_controller_install" {
  count = var.enable_alb_ingress ? 1 : 0

  triggers = {
    cluster_name    = aws_eks_cluster.dbaas_cluster.name
    cluster_endpoint = aws_eks_cluster.dbaas_cluster.endpoint
    role_arn        = aws_iam_role.aws_load_balancer_controller[0].arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Update kubeconfig
      aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.dbaas_cluster.name}

      # Add EKS Helm repo
      helm repo add eks https://aws.github.io/eks-charts
      helm repo update

      # Install AWS Load Balancer Controller
      helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=${aws_eks_cluster.dbaas_cluster.name} \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${aws_iam_role.aws_load_balancer_controller[0].arn}" \
        --set region=${var.region} \
        --set vpcId=${var.vpc_id} \
        --wait --timeout 10m
    EOT
  }

  depends_on = [
    aws_eks_node_group.dbaas_workers,
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}

# Kubernetes Ingress resource for ALB
resource "null_resource" "alb_ingress" {
  count = var.enable_alb_ingress ? 1 : 0

  triggers = {
    domain_name      = local.domain_name
    service_name     = var.dbaas_service_name
    service_port     = var.dbaas_service_port
    namespace        = var.dbaas_namespace
    cluster_name     = aws_eks_cluster.dbaas_cluster.name
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Update kubeconfig
      aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.dbaas_cluster.name}

      # Create namespace if it doesn't exist
      kubectl create namespace ${var.dbaas_namespace} --dry-run=client -o yaml | kubectl apply -f -

      # Create Ingress manifest
      cat <<EOF | kubectl apply -f -
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: dbaas-ui-ingress
        namespace: ${var.dbaas_namespace}
        annotations:
          alb.ingress.kubernetes.io/scheme: internet-facing
          alb.ingress.kubernetes.io/target-type: ip
          alb.ingress.kubernetes.io/healthcheck-path: /
          alb.ingress.kubernetes.io/success-codes: "200,302"
          alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
          alb.ingress.kubernetes.io/subnets: ${join(",", aws_subnet.eks_public[*].id)}
      spec:
        ingressClassName: alb
        rules:
        - host: ${local.domain_name}
          http:
            paths:
            - path: /
              pathType: Prefix
              backend:
                service:
                  name: ${var.dbaas_service_name}
                  port:
                    number: ${var.dbaas_service_port}
      EOF
    EOT
  }

  depends_on = [
    null_resource.aws_load_balancer_controller_install,
    aws_subnet.eks_public,
    aws_route_table_association.eks_public
  ]
}

# Wait for ALB to be provisioned (AWS Load Balancer Controller takes 2-3 minutes)
resource "null_resource" "wait_for_alb" {
  count = var.enable_alb_ingress ? 1 : 0

  triggers = {
    ingress_id = null_resource.alb_ingress[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "⏳ Waiting for ALB to be provisioned by AWS Load Balancer Controller..."
      for i in {1..60}; do
        HOSTNAME=$(kubectl get ingress dbaas-ui-ingress -n ${var.dbaas_namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$HOSTNAME" ]; then
          echo "✅ ALB provisioned: $HOSTNAME"
          exit 0
        fi
        echo "⏳ Waiting... (attempt $i/60)"
        sleep 5
      done
      echo "⚠️  Timeout waiting for ALB, but continuing..."
      exit 0
    EOT
  }

  depends_on = [
    null_resource.alb_ingress
  ]
}

# Data source to get ALB hostname from Ingress
data "kubernetes_ingress_v1" "dbaas_ui" {
  count = var.enable_alb_ingress ? 1 : 0

  metadata {
    name      = "dbaas-ui-ingress"
    namespace = var.dbaas_namespace
  }

  depends_on = [
    null_resource.wait_for_alb
  ]
}

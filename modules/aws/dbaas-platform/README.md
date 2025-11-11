# DBaaS Platform Module

This Terraform module provisions a complete Database-as-a-Service (DBaaS) platform infrastructure on AWS, including:
- **Amazon EKS**: Kubernetes cluster for DBaaS service orchestration
- **Amazon S3**: Object storage for data and backups
- **Networking**: Private subnets and NAT Gateway for EKS
- **IAM**: Roles and policies using IRSA (IAM Roles for Service Accounts)

## Architecture

The module creates a cloud-native DBaaS platform that integrates seamlessly with the `database-cluster` module:

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (Shared)                        │
│                                                             │
│  ┌──────────────────┐         ┌────────────────────────┐  │
│  │ Database Cluster │         │    EKS Private Subnets │  │
│  │  (Public Subnet) │         │   (10.0.10.0/24,       │  │
│  │                  │         │    10.0.11.0/24)       │  │
│  │  ┌────────────┐  │         │                        │  │
│  │  │ VM         │  │         │  ┌──────────────────┐  │  │
│  │  │ Instances  │  │         │  │  EKS Worker      │  │  │
│  │  └────────────┘  │         │  │  Nodes           │  │  │
│  │                  │         │  └──────────────────┘  │  │
│  └──────────────────┘         └────────────────────────┘  │
│           │                              │                 │
│           │                              ↓                 │
│           │                    ┌──────────────────┐       │
│           └───────────────────→│  NAT Gateway     │       │
│                                └──────────────────┘       │
└─────────────────────────────────────────────────────────────┘
                                        │
                                        ↓
                              ┌──────────────────┐
                              │   S3 Buckets     │
                              │  - Storage       │
                              │  - Backups       │
                              └──────────────────┘
```

## Features

### EKS Cluster
- Configurable Kubernetes version (default: 1.33)
- Auto-scaling node groups with spot instance support
- Comprehensive logging enabled (API, audit, authenticator, controller, scheduler)
- OIDC provider for IAM Roles for Service Accounts (IRSA)

### S3 Storage
- Two dedicated buckets (primary storage and backups)
- Server-side encryption (AES256)
- Versioning enabled with lifecycle policies
- Public access completely blocked
- Configurable retention policies

### Networking
- Private subnets across multiple availability zones
- NAT Gateway for outbound internet access
- Integration with existing VPC from database-cluster module
- Kubernetes-specific subnet tagging

### Security
- IRSA-based S3 access (no long-lived credentials)
- Least privilege IAM policies
- Encrypted S3 buckets
- Network isolation via private subnets

## Usage

### Basic Usage

```hcl
module "database_cluster" {
  source = "../../modules/aws/database-cluster"

  region       = "us-west-2"
  env_prefix   = "dev-alice"
  vm_count     = 3
  instance_type = "c7i.4xlarge"

  # ... other database cluster configuration
}

module "dbaas_platform" {
  source = "../../modules/aws/dbaas-platform"

  # Required inputs from database cluster
  region           = "us-west-2"
  env_prefix       = "dev-alice"
  vpc_id           = module.database_cluster.vpc_id
  public_subnet_id = module.database_cluster.subnet_id

  # EKS configuration
  eks_cluster_version     = "1.33"
  eks_node_instance_types = ["t3.xlarge"]
  eks_desired_capacity    = 4
  eks_max_capacity        = 8
  use_spot_instances      = true

  # S3 configuration
  enable_s3_versioning = true
  s3_lifecycle_days    = 30

  # Tags
  common_tags = {
    Project     = "Cloudberry DBaaS"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}
```

### Conditional Deployment

```hcl
variable "deploy_dbaas_platform" {
  description = "Whether to deploy DBaaS platform infrastructure"
  type        = bool
  default     = true
}

module "dbaas_platform" {
  count  = var.deploy_dbaas_platform ? 1 : 0
  source = "../../modules/aws/dbaas-platform"

  # ... configuration
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| region | AWS region for DBaaS resources | string | - | yes |
| env_prefix | Environment prefix for resource naming | string | - | yes |
| vpc_id | VPC ID from the database cluster module | string | - | yes |
| public_subnet_id | Public subnet ID for NAT Gateway | string | - | yes |
| availability_zones | List of AZs to use for EKS subnets | list(string) | [] | no |
| eks_cluster_version | Kubernetes version for EKS cluster | string | "1.33" | no |
| eks_node_instance_types | Instance types for EKS worker nodes | list(string) | ["t3.xlarge"] | no |
| eks_desired_capacity | Desired number of EKS worker nodes | number | 4 | no |
| eks_max_capacity | Maximum number of EKS worker nodes | number | 8 | no |
| eks_min_capacity | Minimum number of EKS worker nodes | number | 1 | no |
| use_spot_instances | Use spot instances for EKS worker nodes | bool | false | no |
| enable_s3_versioning | Enable versioning on S3 buckets | bool | true | no |
| s3_lifecycle_days | Days to retain objects in S3 | number | 30 | no |
| s3_noncurrent_version_days | Days to retain noncurrent versions | number | 7 | no |
| common_tags | Common tags to apply to all resources | map(string) | {} | no |
| service_account_namespace | Kubernetes namespace for service account | string | "default" | no |
| service_account_name | Name of Kubernetes service account | string | "dbaas-s3-access" | no |

## Outputs

| Name | Description |
|------|-------------|
| eks_cluster_name | Name of the EKS cluster |
| eks_cluster_endpoint | Endpoint for EKS cluster API server |
| eks_cluster_arn | ARN of the EKS cluster |
| eks_kubeconfig_command | Command to configure kubectl |
| s3_storage_bucket_id | ID of the primary storage S3 bucket |
| s3_backup_bucket_id | ID of the backup S3 bucket |
| dbaas_s3_role_arn | ARN of the IAM role for S3 access (IRSA) |
| eks_private_subnet_ids | IDs of the private subnets used by EKS |
| nat_gateway_public_ip | Public IP address of the NAT Gateway |
| service_account_annotation | Annotation to add to K8s service account |
| dbaas_platform_summary | Summary of all DBaaS platform resources |

## Post-Deployment Setup

### 1. Configure kubectl

```bash
# Get the kubeconfig command from terraform output
terraform output eks_kubeconfig_command

# Execute the command (example)
aws eks update-kubeconfig --region us-west-2 --name dev-alice-dbaas-cluster

# Verify connection
kubectl get nodes
```

### 2. Create Service Account with IRSA

```bash
# Get the role ARN
ROLE_ARN=$(terraform output -raw dbaas_s3_role_arn)

# Create service account (name must match module configuration)
kubectl create serviceaccount dbaas-s3-access

# Annotate with IAM role
kubectl annotate serviceaccount dbaas-s3-access \
  eks.amazonaws.com/role-arn=$ROLE_ARN
```

### 3. Test S3 Access from Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: s3-test
spec:
  serviceAccountName: dbaas-s3-access
  containers:
  - name: aws-cli
    image: amazon/aws-cli:latest
    command: ["sleep", "3600"]
```

```bash
# Apply test pod
kubectl apply -f test-pod.yaml

# Verify S3 access
kubectl exec s3-test -- aws s3 ls
```

## Cost Optimization

### Spot Instances
Enable spot instances for EKS worker nodes to save 60-90% on compute costs:

```hcl
use_spot_instances = true
```

### S3 Lifecycle Policies
The module includes automatic object expiration and version cleanup:
- Objects expire after 30 days (configurable via `s3_lifecycle_days`)
- Noncurrent versions deleted after 7 days (configurable via `s3_noncurrent_version_days`)

### Right-Sizing
- Default instance type: `t3.xlarge` (4 vCPU, 16GB RAM)
- Auto-scaling: Scale down to 1 node minimum during idle periods
- NAT Gateway: Single NAT for cost savings (~$32/month vs ~$96/month for multi-AZ)

## Expected Monthly Costs

| Component | Cost (USD) | Notes |
|-----------|------------|-------|
| EKS Control Plane | $73 | Fixed cost |
| EKS Worker Nodes (4x t3.xlarge) | $120-140 | With spot instances |
| EBS Storage (EKS nodes) | $15-25 | Based on node count |
| S3 Storage | $5-15 | Development usage |
| NAT Gateway | $32 | Single AZ |
| **Total** | **$245-285** | **Development environment** |

## Security Considerations

### IRSA Configuration
- Service account name and namespace are configurable
- Trust policy automatically configured for specified service account
- Scoped to specific S3 buckets only

### Network Security
- EKS nodes in private subnets (no direct internet exposure)
- NAT Gateway for outbound traffic only
- Security groups managed by EKS

### S3 Security
- All public access blocked
- Server-side encryption enabled
- Bucket policies enforce HTTPS
- IRSA provides temporary credentials (no static keys)

## DBaaS Application Integration

This module provides the infrastructure foundation for deploying database-as-a-service applications:

1. **Container Registry**: Configure image pull from your container registry
2. **Deploy CRDs**: Deploy custom resource definitions for database management
3. **Deploy Operators**: Deploy Kubernetes operators for lifecycle management
4. **Deploy Services**: Deploy application services and web consoles

Deployment instructions for specific DBaaS applications will be provided separately.

## Troubleshooting

### EKS Access Issues
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check EKS cluster status
aws eks describe-cluster --name <cluster-name> --region <region>

# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

### S3 Access Issues
```bash
# Verify IRSA role
kubectl describe serviceaccount dbaas-s3-access

# Check pod identity
kubectl exec <pod-name> -- aws sts get-caller-identity

# Test S3 access
kubectl exec <pod-name> -- aws s3 ls s3://<bucket-name>/
```

### Network Connectivity
```bash
# Check VPC configuration
aws ec2 describe-vpcs --vpc-id <vpc-id>

# Verify NAT Gateway status
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>"

# Test internet connectivity from pod
kubectl run test-curl --image=curlimages/curl:latest --rm -i --restart=Never -- curl -s https://api.ipify.org
```

## Examples

See the `rl9-synxdb-elastic` environment for a complete working example integrating both the database-cluster and dbaas-platform modules.

## Requirements

- Terraform >= 1.0
- AWS Provider ~> 5.0
- Existing VPC and public subnet (from database-cluster module)
- AWS credentials with appropriate permissions

## License

This module is part of the Cloudberry Development Environment Launcher project.

---

**Generated**: $(date)
**Module Version**: 1.0.0
**Terraform**: >= 1.0

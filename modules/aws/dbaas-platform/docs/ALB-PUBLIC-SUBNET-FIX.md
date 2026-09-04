# ALB Public Subnet Fix - November 18, 2025

## Issue Summary

**Problem**: ALB ingress failed to provision with error:
```
Failed build model due to couldn't auto-discover subnets: subnets count less than minimal required count: 1 < 2
```

**Root Cause**:
- Internet-facing ALB requires **minimum 2 public subnets** in different availability zones
- Infrastructure only had **1 public subnet** (from database-cluster module)
- EKS private subnets were tagged with `kubernetes.io/role/internal-elb` (for internal ALBs only)

**Previous Working State**:
- Had 3 public subnets manually created or from previous Terraform (since removed)
- Subnets: `subnet-0f0765f5b8bb3b6bd`, `subnet-05942acd7efc76c93`, `subnet-00c0e1374bbe2db43`
- These were destroyed during teardown and not recreated

## Solution Implemented

### 1. Created Public Subnets in Terraform

**File**: `modules/aws/dbaas-platform/networking.tf`

Added 3 public subnets across different availability zones:

```terraform
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
    "kubernetes.io/role/elb" = "1"  # Required for internet-facing ALB
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
  })
}
```

**Key Configuration**:
- CIDR blocks: `10.0.2.0/24`, `10.0.3.0/24`, `10.0.4.0/24`
- Tag: `kubernetes.io/role/elb=1` (enables ALB auto-discovery)
- `map_public_ip_on_launch = true` (makes them public)

### 2. Added Route Table for Public Subnets

```terraform
# Route table for public subnets (using existing IGW from database-cluster module)
data "aws_internet_gateway" "main" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

resource "aws_route_table" "eks_public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.main.id
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
```

### 3. Updated NAT Gateway

Moved NAT Gateway to use new public subnets:

```terraform
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.eks_public[0].id  # Use first new public subnet

  depends_on = [
    aws_eip.nat,
    aws_subnet.eks_public
  ]
}
```

### 4. Updated ALB Ingress Configuration

**File**: `modules/aws/dbaas-platform/alb.tf`

Added subnet annotation to ingress template:

```terraform
annotations:
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip
  alb.ingress.kubernetes.io/healthcheck-path: /
  alb.ingress.kubernetes.io/success-codes: "200,302"
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
  alb.ingress.kubernetes.io/subnets: ${join(",", aws_subnet.eks_public[*].id)}  # NEW
```

Added dependency:
```terraform
depends_on = [
  null_resource.aws_load_balancer_controller_install,
  aws_subnet.eks_public,
  aws_route_table_association.eks_public
]
```

### 5. Added Outputs

**File**: `modules/aws/dbaas-platform/outputs.tf`

```terraform
output "eks_public_subnet_ids" {
  description = "IDs of the public subnets for ALB"
  value       = aws_subnet.eks_public[*].id
}

output "eks_public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.eks_public[*].cidr_block
}
```

### 6. Fixed deploy.sh Health Check

**File**: `environments/synx/rl9-synx-elastic/deploy.sh`

**Problem**: Script queried ALL target groups matching pattern, returning multiple ARNs (old + new)

**Solution**: Query target groups specifically attached to the current ALB:

```bash
# Get load balancer ARN from the ALB hostname
ALB_ARN=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
  --query "LoadBalancers[?DNSName=='$ALB_HOSTNAME'].LoadBalancerArn" \
  --output text 2>/dev/null || echo "")

# Get target groups for this specific ALB
TG_ARNS=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --load-balancer-arn "$ALB_ARN" \
  --query 'TargetGroups[*].TargetGroupArn' \
  --output text 2>/dev/null || echo "")

# Check health of first target group
TG_ARN=$(echo "$TG_ARNS" | awk '{print $1}')
```

## Deployment Results

### Terraform Changes Applied
```
Plan: 8 to add, 1 to change, 1 to destroy.

Resources Added:
- 3 x aws_subnet.eks_public (public subnets)
- 1 x aws_route_table.eks_public (route table)
- 3 x aws_route_table_association.eks_public (associations)
- 1 x data.aws_internet_gateway.main (IGW lookup)

Resources Changed:
- 1 x aws_route_table.eks_private (updated for new NAT)

Resources Destroyed/Recreated:
- 1 x aws_nat_gateway.main (moved to new subnet)
```

### Current ALB Configuration

**ALB Details**:
- DNS: `k8s-dbaas-dbaasuii-d3a5e8b876-1906603287.us-west-2.elb.amazonaws.com`
- Scheme: `internet-facing`
- Status: Healthy and responding (HTTP 200)

**Subnets**:
- `subnet-0e7ce7ba706026b0e` (us-west-2a, 10.0.2.0/24)
- `subnet-034468bac84d030eb` (us-west-2b, 10.0.3.0/24)
- `subnet-02cead5616cf2d7fd` (us-west-2c, 10.0.4.0/24)

**Verification**:
```bash
# ALB responds correctly with Host header
curl -I -H "Host: synxdb-elastic-demo.synxdata.us" \
  http://k8s-dbaas-dbaasuii-d3a5e8b876-1906603287.us-west-2.elb.amazonaws.com/ops/
# Returns: HTTP/1.1 200
```

## Files Modified

1. **`modules/aws/dbaas-platform/networking.tf`**
   - Added public subnet resources (3 subnets)
   - Added route table and associations
   - Updated NAT gateway to use new subnets

2. **`modules/aws/dbaas-platform/alb.tf`**
   - Added subnet annotation to ingress template
   - Added dependencies on public subnets

3. **`modules/aws/dbaas-platform/outputs.tf`**
   - Added public subnet IDs output
   - Added public subnet CIDRs output

4. **`environments/synx/rl9-synx-elastic/deploy.sh`**
   - Fixed target group health check logic in `cmd_wait_alb()`

## Future Deployments

### Automatic Application

✅ **Will Apply Automatically**:
- Public subnets will be created (in Terraform)
- Route tables and associations configured
- NAT gateway properly placed
- Ingress template includes subnet annotation

⚠️ **Existing Deployments**:
For existing deployments to pick up ingress changes:
```bash
terraform taint 'module.dbaas_platform[0].null_resource.alb_ingress[0]'
terraform apply
```

✅ **Fresh Deployments**:
Everything works automatically after `terraform apply`

### Testing New Deployments

1. **Deploy infrastructure**:
   ```bash
   ./deploy.sh infra
   ```

2. **Deploy Helm charts**:
   ```bash
   ./deploy.sh helm
   ```

3. **Wait for ALB** (now with working health checks):
   ```bash
   ./deploy.sh wait-alb
   ```

4. **Verify**:
   ```bash
   kubectl get ingress -n dbaas
   # Should show internet-facing ALB with address
   ```

## Key Takeaways

### Why This Happened

1. **Infrastructure was incomplete**: Only 1 public subnet existed (from database-cluster module)
2. **Previous working state relied on manual resources**: 3 public subnets that were destroyed during teardown
3. **Terraform didn't codify the full working state**: Public subnets for ALB were not in IaC

### What We Fixed

1. **Codified public subnets in Terraform**: Now repeatable and documented
2. **Proper subnet tagging**: `kubernetes.io/role/elb=1` for ALB auto-discovery
3. **Fixed deploy.sh**: Health checks now query correct target group
4. **Infrastructure is complete**: All future deployments will work correctly

### Architecture

```
Internet
  ↓
Internet Gateway (from database-cluster module)
  ↓
Public Subnets (NEW - 3 across us-west-2a, 2b, 2c)
  ├─ Internet-facing ALB (AWS Load Balancer Controller)
  └─ NAT Gateway
      ↓
Private Subnets (existing - 2 across us-west-2a, 2b)
  └─ EKS Worker Nodes
      └─ DBaaS Integration Pods (target: 10.0.11.225:8030)
```

## Troubleshooting Reference

### If ALB fails to provision

**Check**: Subnet tags
```bash
aws ec2 describe-subnets --subnet-ids subnet-xxx \
  --query 'Subnets[0].Tags'
```
Should have: `kubernetes.io/role/elb = 1`

**Check**: ALB controller logs
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
```

### If targets unhealthy

**Check**: Target group health
```bash
TG_ARN="arn:aws:elasticloadbalancing:..."
aws elbv2 describe-target-health --target-group-arn $TG_ARN --region us-west-2
```

**Check**: Service endpoints
```bash
kubectl get endpoints dbaas-integration -n dbaas
```

### If DNS not resolving

**Check**: Ingress status
```bash
kubectl get ingress dbaas-ui-ingress -n dbaas
# Should show ADDRESS with ALB hostname
```

## Related Documentation

- Main deployment docs: `DEPLOYMENT-STATUS-EXTERNAL-ACCESS.md`
- External access setup: `EXTERNAL-ACCESS-SETUP.md`
- DBaaS platform module: `../../../modules/aws/dbaas-platform/README.md`

---

**Document Created**: November 18, 2025
**Issue Resolved**: Internet-facing ALB with public subnets
**Status**: ✅ Complete and tested
**Next Review**: Before next major infrastructure teardown/rebuild

# DBaaS Platform Deployment Guide

**Last Updated**: 2025-11-17
**Environment**: rl9-synx-elastic
**Status**: Production Ready ✅

## Table of Contents

1. [Quick Start](#quick-start)
2. [Deployment Script Usage](#deployment-script-usage)
3. [Step-by-Step Deployment](#step-by-step-deployment)
4. [External DNS Setup](#external-dns-setup)
5. [Troubleshooting](#troubleshooting)
6. [Teardown](#teardown)
7. [Architecture Overview](#architecture-overview)

---

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- kubectl configured (will be auto-configured by script)
- Terraform installed
- SSH access to VM (key in current directory)
- Cloudflare API token (for DNS)

### Full Deployment

```bash
# Set Cloudflare API token
export TF_VAR_cloudflare_api_token="your-token-here"

# Run full deployment
./deploy.sh all
```

### Individual Steps

```bash
./deploy.sh infra      # Step 1: Deploy infrastructure
./deploy.sh helm       # Step 2: Deploy applications
./deploy.sh wait-alb   # Step 3: Wait for ALB
./deploy.sh dns        # Step 4: Create DNS record
./deploy.sh verify     # Step 5: Verify deployment
```

---

## Deployment Script Usage

The `deploy.sh` script provides a unified interface for all deployment operations.

### Commands

```bash
./deploy.sh <command>
```

| Command | Description |
|---------|-------------|
| `infra` | Deploy infrastructure with Terraform (Step 1) |
| `helm` | Deploy Helm charts on remote VM (Step 2) |
| `wait-alb` | Wait for ALB to be provisioned (Step 3) |
| `dns` | Create DNS record via Terraform (Step 4) |
| `verify` | Verify complete deployment (Step 5) |
| `all` | Run all steps in sequence |
| `teardown` | Destroy all infrastructure |
| `help` | Show help message |

### Environment Variables

The script uses environment variables from `.envrc`:

- `TF_VAR_cloudflare_api_token` - Cloudflare API token (required for DNS)
- `TF_VAR_default_username` - SSH username (default: rocky)
- `TF_VAR_env_prefix` - Environment prefix
- `TF_VAR_region` - AWS region (default: us-west-2)

---

## Step-by-Step Deployment

### Step 1: Deploy Infrastructure

```bash
./deploy.sh infra
```

**What it does:**
- Creates EKS cluster (Kubernetes 1.34)
- Creates RDS PostgreSQL database
- Creates S3 buckets (storage and backups)
- Deploys AWS Load Balancer Controller
- Creates Kubernetes Ingress resource (no ALB yet)
- Creates EC2 VM instance (for running helm commands)

**Duration:** ~15-20 minutes

**Output:**
- VM IP address
- EKS cluster name

**Verification:**
```bash
terraform output
kubectl get nodes
```

---

### Step 2: Deploy Helm Charts

```bash
./deploy.sh helm
```

**What it does:**
- SSHs to remote VM
- Deploys FDB Operator (FoundationDB)
- Deploys CloudBeaver (database UI)
- Deploys DBaaS Integration (main application)

**Duration:** ~10-15 minutes (includes helm --wait)

**Critical:** The `dbaas-integration` service MUST exist before ALB can be provisioned.

**Verification:**
```bash
kubectl get pods -n dbaas
kubectl get svc dbaas-integration -n dbaas
kubectl get endpoints dbaas-integration -n dbaas
```

**Expected output:**
```
NAME                TYPE        CLUSTER-IP      PORT(S)
dbaas-integration   ClusterIP   172.20.x.x      8030/TCP,28030/TCP

# Endpoints should show pod IP(s)
```

---

### Step 3: Wait for ALB Provisioning

```bash
./deploy.sh wait-alb
```

**What it does:**
- Verifies dbaas-integration service exists
- Waits for ALB Controller to provision the ALB (2-3 minutes)
- Monitors target health

**Duration:** 2-5 minutes

**How it works:**
1. ALB Controller watches the ingress resource
2. Detects dbaas-integration service is ready
3. Creates Application Load Balancer
4. Creates target groups
5. Registers pod IPs as targets
6. Updates ingress status with ALB hostname

**Verification:**
```bash
kubectl get ingress -n dbaas dbaas-ui-ingress
```

**Expected output:**
```
NAME               CLASS   HOSTS                   ADDRESS
dbaas-ui-ingress   alb     synxdb-elastic-demo...  k8s-dbaas-dbaasuii-xxx.elb.amazonaws.com
```

**Troubleshooting:**
If ALB doesn't appear after 5 minutes, check:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
```

Common issues:
- IAM permissions missing (see [IAM Permissions Required](#iam-permissions-required))
- Service endpoints not ready
- Subnet annotations missing

---

### Step 4: Create DNS Record

```bash
./deploy.sh dns
```

**What it does:**
- Verifies ALB exists
- Uses Terraform to create Cloudflare DNS CNAME record
- Points domain to ALB hostname

**Duration:** ~30 seconds + DNS propagation (1-5 minutes)

**Terraform command used:**
```bash
terraform apply -replace='module.dbaas_platform[0].null_resource.cloudflare_dns_record[0]'
```

**DNS Record Created:**
- **Type:** CNAME
- **Name:** synxdb-elastic-demo.synxdata.us
- **Target:** k8s-dbaas-dbaasuii-xxx.elb.amazonaws.com
- **Proxied:** false (direct to ALB)

**Verification:**
```bash
dig +short synxdb-elastic-demo.synxdata.us
```

---

### Step 5: Verify Deployment

```bash
./deploy.sh verify
```

**What it does:**
- Tests DNS resolution
- Tests HTTP connectivity to all endpoints
- Shows Kubernetes resource status

**Access URLs:**
- Operations Dashboard: http://synxdb-elastic-demo.synxdata.us/ops/
- User Console: http://synxdb-elastic-demo.synxdata.us/console/
- Health Check: http://synxdb-elastic-demo.synxdata.us/actuator/health

---

## External DNS Setup

### Overview

External DNS is configured using:
- **Cloudflare** for DNS management
- **Application Load Balancer (ALB)** for ingress
- **AWS Load Balancer Controller** for ALB provisioning
- **Terraform** for DNS record automation

### Architecture

```
Internet
  ↓
Cloudflare DNS (synxdb-elastic-demo.synxdata.us)
  ↓
Application Load Balancer (ALB)
  ↓ [3 subnets: 1 public, 2 private]
Target Group (IP mode)
  ↓
DBaaS Integration Pods (in private subnets)
```

### IAM Permissions Required

The AWS Load Balancer Controller requires specific IAM permissions. During initial deployment, we encountered missing permissions that had to be added:

#### Required Permissions (Added)

1. **ec2:DescribeRouteTables**
   - **Why:** ALB Controller needs to discover subnet routing to determine public vs private subnets
   - **Error without it:** "couldn't auto-discover subnets"
   - **Location:** `modules/aws/dbaas-platform/alb.tf:44`

2. **elasticloadbalancing:AddTags**
   - **Why:** Tags must be added when creating target groups and load balancers
   - **Error without it:** "User is not authorized to perform: elasticloadbalancing:AddTags"
   - **Location:** `modules/aws/dbaas-platform/alb.tf:152-167`

3. **elasticloadbalancing:DescribeListenerAttributes**
   - **Why:** ALB Controller needs to read listener configuration
   - **Error without it:** "User is not authorized to perform: elasticloadbalancing:DescribeListenerAttributes"
   - **Location:** `modules/aws/dbaas-platform/alb.tf:55`

#### IAM Policy Location

The complete IAM policy is defined in:
```
modules/aws/dbaas-platform/alb.tf
```

Resource: `aws_iam_policy.aws_load_balancer_controller`

### Subnet Configuration

The ALB requires at least 2 subnets in different availability zones.

**Current subnet configuration:**
- 1 public subnet: `subnet-0529778708ea9457b` (us-west-2c, 10.0.1.0/24)
- 2 private subnets:
  - `subnet-053eab526b9a1d4b0` (us-west-2a, 10.0.10.0/24)
  - `subnet-042ee81d41faf5ebf` (us-west-2b, 10.0.11.0/24)

**Ingress annotation required:**
```yaml
alb.ingress.kubernetes.io/subnets: subnet-0529778708ea9457b,subnet-053eab526b9a1d4b0,subnet-042ee81d41faf5ebf
```

This annotation was added because the ALB Controller couldn't auto-discover enough public subnets (only 1 exists).

### DNS Automation

Terraform automatically creates the Cloudflare DNS record, but **only after** the ALB is provisioned.

**Timing is critical:**
1. ❌ First `terraform apply` (infrastructure) - ALB doesn't exist yet, DNS creation skipped
2. ✅ Helm deployment - dbaas-integration service created, ALB provisioned
3. ✅ Second `terraform apply` (dns) - ALB exists, DNS record created

**Destroy provisioner:**
The Cloudflare DNS record has a destroy provisioner that automatically deletes the DNS record when you run `terraform destroy`.

Location: `modules/aws/dbaas-platform/cloudflare.tf:58-74`

---

## Troubleshooting

### Common Deployment Issues

#### Issue 1: ALB Not Provisioned

**Symptoms:**
- Ingress shows no ADDRESS after 5+ minutes
- `kubectl get ingress -n dbaas` shows empty ADDRESS column

**Causes & Solutions:**

1. **Missing IAM Permissions**
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
   ```
   Look for "not authorized" errors. See [IAM Permissions Required](#iam-permissions-required).

2. **Service Not Ready**
   ```bash
   kubectl get svc dbaas-integration -n dbaas
   kubectl get endpoints dbaas-integration -n dbaas
   ```
   Ensure service has endpoints (pod IPs).

3. **Subnet Discovery Failed**
   ```bash
   kubectl describe ingress dbaas-ui-ingress -n dbaas
   ```
   Check events for subnet-related errors.

#### Issue 2: Target Health Unhealthy

**Symptoms:**
- ALB provisioned but shows unhealthy targets
- HTTP 502/503 errors

**Check target health:**
```bash
TG_ARN=$(aws elbv2 describe-target-groups --region us-west-2 \
  --query "TargetGroups[?contains(TargetGroupName, 'dbaas-dbaasint')].TargetGroupArn" \
  --output text)

aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region us-west-2
```

**Common causes:**
- Health check path returning 302 instead of 200
  - **Solution:** Added `alb.ingress.kubernetes.io/success-codes: "200,302"`
- Pods not ready
- Security group rules blocking traffic

#### Issue 3: DNS Not Resolving

**Symptoms:**
- `dig synxdb-elastic-demo.synxdata.us` returns no results
- DNS propagation taking longer than expected

**Verification:**
```bash
# Check if DNS record was created in Cloudflare
curl -s "https://api.cloudflare.com/client/v4/zones/4b012d8134d971ea49aee0f197cc065b/dns_records?name=synxdb-elastic-demo.synxdata.us" \
  -H "Authorization: Bearer $TF_VAR_cloudflare_api_token" | jq '.result'
```

**Solutions:**
- Wait 1-5 minutes for DNS propagation
- Verify Cloudflare API token is set
- Re-run: `./deploy.sh dns`

---

## Teardown

### Automated Teardown (Recommended)

```bash
./deploy.sh teardown
```

**What it does:**

**Phase 1: Pre-cleanup (Automated)**
1. Deletes Kubernetes ingress resource via kubectl
2. Waits for ALB Controller to delete the ALB (up to 5 minutes)
3. Waits for security groups to be automatically cleaned up
4. Handles cases where kubectl isn't available

**Phase 2: Terraform Destroy**
5. Runs `terraform destroy` to remove all infrastructure

**Duration:** 10-15 minutes

### Why Pre-cleanup is Important

Without pre-cleanup, you may encounter:
- **Stuck subnet deletion** (ENIs still attached)
- **Stuck VPC deletion** (security groups not deleted)
- **Manual cleanup required** (delete ALB and security groups manually)

### Manual Cleanup (If Needed)

If you already ran `terraform destroy` and it's stuck:

#### Delete ALB
```bash
aws elbv2 delete-load-balancer \
  --load-balancer-arn $(aws elbv2 describe-load-balancers --region us-west-2 \
    --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-dbaas')].LoadBalancerArn" \
    --output text)
```

#### Delete Security Groups
```bash
# List security groups
aws ec2 describe-security-groups \
  --region us-west-2 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'SecurityGroups[*].[GroupId,GroupName]'

# Delete (replace with actual IDs)
aws ec2 delete-security-group --group-id sg-xxxxx --region us-west-2
```

#### Check for Stuck ENIs
```bash
aws ec2 describe-network-interfaces \
  --region us-west-2 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'NetworkInterfaces[*].[NetworkInterfaceId,Description,Status]'
```

---

## Architecture Overview

### Infrastructure Components

| Component | Resource | Purpose |
|-----------|----------|---------|
| EKS Cluster | Kubernetes 1.34 | Container orchestration |
| RDS PostgreSQL | db.t3.micro | Application database |
| S3 Buckets | storage + backups | Object storage |
| ALB | Application Load Balancer | HTTP/HTTPS ingress |
| NAT Gateway | Single NAT | Private subnet internet access |
| VPC | 10.0.0.0/16 | Network isolation |
| Subnets | 1 public, 2 private | Multi-AZ deployment |

### Network Topology

```
VPC (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24) - us-west-2c
│   ├── NAT Gateway
│   └── ALB ENI
├── Private Subnet 1 (10.0.10.0/24) - us-west-2a
│   ├── EKS Pods
│   └── ALB ENI
└── Private Subnet 2 (10.0.11.0/24) - us-west-2b
    ├── EKS Pods
    └── ALB ENI
```

### Application Stack

```
┌─────────────────────────────────────┐
│  Kubernetes Cluster (EKS)           │
├─────────────────────────────────────┤
│  Namespace: fdb                     │
│    - FoundationDB Operator          │
├─────────────────────────────────────┤
│  Namespace: cloudbeaver             │
│    - CloudBeaver (Database UI)      │
├─────────────────────────────────────┤
│  Namespace: dbaas                   │
│    - DBaaS Integration (Main App)   │
│    - Service: dbaas-integration     │
│    - Ingress: dbaas-ui-ingress      │
└─────────────────────────────────────┘
```

---

## Additional Resources

### Related Documentation

- [DEPLOYMENT-STATUS-EXTERNAL-ACCESS.md](./DEPLOYMENT-STATUS-EXTERNAL-ACCESS.md) - Previous deployment attempts and troubleshooting
- [EXTERNAL-ACCESS-SETUP.md](./EXTERNAL-ACCESS-SETUP.md) - Original setup guide (NLB-based, deprecated)
- [synx-elastic-s3-CLAUDE.md](./synx-elastic-s3-CLAUDE.md) - S3 and database migration guide

### Key Configuration Files

- `deploy.sh` - Unified deployment script
- `terraform.tfvars` - Terraform variables
- `.envrc` - Environment variables (including Cloudflare token)
- `.env` - Shell functions (get_instance_ip, etc.)

### AWS Resources

- ALB Controller Docs: https://kubernetes-sigs.github.io/aws-load-balancer-controller/
- EKS User Guide: https://docs.aws.amazon.com/eks/latest/userguide/
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/

---

## Change Log

### 2025-11-17
- ✅ Added automated external DNS setup
- ✅ Fixed IAM permissions for ALB Controller
- ✅ Added explicit subnet annotations to ingress
- ✅ Created unified deploy.sh script
- ✅ Automated pre-cleanup in teardown process
- ✅ Documented complete deployment workflow

### Previous History
- See [DEPLOYMENT-STATUS-EXTERNAL-ACCESS.md](./DEPLOYMENT-STATUS-EXTERNAL-ACCESS.md) for earlier attempts

---

**Deployment Status:** ✅ Production Ready
**External DNS:** ✅ Working
**Automated Teardown:** ✅ Implemented
**Documentation:** ✅ Complete

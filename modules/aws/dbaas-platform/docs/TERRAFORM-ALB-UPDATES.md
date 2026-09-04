# Terraform Configuration Updated for ALB

> Relocated from the module root. Notes from the ALB external-access work; `README.md` is the
> module's current reference.

**Date**: November 14, 2025  
**Status**: ✅ Terraform Now Reflects Working Configuration

## Changes Made

The Terraform configuration has been updated to properly deploy the working ALB-based external access configuration.

### New Files Created

1. **`alb.tf`** - Complete ALB configuration
   - IAM policy for AWS Load Balancer Controller
   - IAM role with OIDC trust for EKS service account
   - Helm deployment of AWS Load Balancer Controller
   - Kubernetes Ingress resource configuration
   - Data source to fetch ALB hostname

### Files Updated

1. **`variables.tf`**
   - Added `enable_alb_ingress` variable (recommended)
   - Marked `enable_nlb_ingress` as deprecated
   
2. **`cloudflare.tf`**
   - Updated to support both ALB and NLB
   - Uses ALB hostname when `enable_alb_ingress = true`
   - Falls back to NLB when using legacy configuration

3. **`nlb.tf`**, **`helm.tf`**
   - Added deprecation warnings
   - Kept for backward compatibility

### How to Use

#### For New Deployments (Recommended)

Update your `terraform.tfvars`:

```hcl
# Use ALB-based external access (RECOMMENDED)
enable_alb_ingress = true

# Cloudflare DNS configuration
enable_cloudflare_dns    = true
cloudflare_zone_id       = "your-zone-id"
cloudflare_api_token     = "your-api-token"  
cloudflare_proxy_enabled = false  # Set to false for HTTP-only initially
dbaas_domain_name        = "synxdb-elastic.synxdata.com"

# Service configuration
dbaas_namespace    = "dbaas"
dbaas_service_name = "dbaas-integration"
dbaas_service_port = 8030
```

#### Applying Changes

```bash
cd environments/synx/rl9-synx-elastic

# Initialize (if needed)
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

### What Gets Deployed

When `enable_alb_ingress = true`:

1. **IAM Resources**
   - Policy: `AWSLoadBalancerControllerIAMPolicy-{env_prefix}`
   - Role: `AmazonEKSLoadBalancerControllerRole-{env_prefix}`
   - OIDC trust relationship for EKS service account

2. **AWS Load Balancer Controller**
   - Deployed via Helm to `kube-system` namespace
   - Service account: `aws-load-balancer-controller`
   - Annotated with IAM role ARN

3. **Kubernetes Ingress**
   - Name: `dbaas-ui-ingress`
   - Namespace: `dbaas` (or configured namespace)
   - IngressClass: `alb`
   - Annotations:
     - `alb.ingress.kubernetes.io/scheme: internet-facing`
     - `alb.ingress.kubernetes.io/target-type: ip`
     - `alb.ingress.kubernetes.io/healthcheck-path: /`
     - `alb.ingress.kubernetes.io/success-codes: "200,302"`
     - `alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'`

4. **Application Load Balancer**
   - Created automatically by AWS Load Balancer Controller
   - Scheme: internet-facing
   - Targets: EKS pods via IP mode
   - Listener: HTTP port 80

5. **Cloudflare DNS**
   - CNAME record pointing to ALB hostname
   - Automatically updated from Ingress status

### Migration from Manual Deployment

If you have a manually deployed ALB (like the current production):

**Option 1: Clean Slate** (Recommended for testing)
1. Delete manual resources (Ingress, Helm release, IAM role)
2. Run `terraform apply` to create fresh resources

**Option 2: Import Existing** (Advanced)
```bash
# Import IAM role
terraform import 'module.dbaas_platform[0].aws_iam_role.aws_load_balancer_controller[0]' AmazonEKSLoadBalancerControllerRole-eespino-synx2

# Import IAM policy  
terraform import 'module.dbaas_platform[0].aws_iam_policy.aws_load_balancer_controller[0]' arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy2

# Note: Helm releases and Kubernetes resources cannot be imported into null_resource
# You'll need to recreate those or use a different approach
```

### Adding HTTPS Support

To add HTTPS in the future:

1. **Create ACM Certificate**:
   ```bash
   aws acm request-certificate \
     --domain-name synxdb-elastic.synxdata.com \
     --validation-method DNS \
     --region us-west-2
   ```

2. **Update Ingress Annotations** in `alb.tf`:
   ```hcl
   alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
   alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:ACCOUNT:certificate/CERT_ID
   alb.ingress.kubernetes.io/ssl-redirect: '443'
   ```

3. **Update Cloudflare**:
   ```hcl
   cloudflare_proxy_enabled = true  # Enable orange cloud
   ```

4. **Apply Changes**:
   ```bash
   terraform apply
   ```

### Backward Compatibility

The old NLB configuration still works if needed:

```hcl
enable_nlb_ingress = true  # Use old NLB approach
enable_alb_ingress = false  # Disable new ALB approach
```

However, NLB is **deprecated** and may fail due to network topology issues.

### Outputs

After applying, Terraform will provide:

- ALB hostname (from Ingress status)
- Cloudflare DNS record details
- IAM role ARN
- Access URL

### Troubleshooting

**Issue**: ALB not created after Ingress is applied
- **Solution**: Wait 2-3 minutes for AWS Load Balancer Controller to provision ALB
- **Check**: `kubectl describe ingress dbaas-ui-ingress -n dbaas`

**Issue**: Ingress shows no load balancer hostname
- **Solution**: Check AWS Load Balancer Controller logs
- **Command**: `kubectl logs -n kube-system deployment/aws-load-balancer-controller`

**Issue**: Cloudflare DNS not updating
- **Solution**: Verify Ingress has load balancer hostname first
- **Check**: `kubectl get ingress dbaas-ui-ingress -n dbaas -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`

## Summary

Terraform configuration is now properly aligned with the working ALB-based deployment. Future deployments using `enable_alb_ingress = true` will create the same infrastructure that was manually deployed and verified to work.

**Configuration**: `/Users/eespino/workspace/Synx-Data-Labs/cloudberry-dev-env-launcher/modules/aws/dbaas-platform/alb.tf`  
**Variables**: Use `enable_alb_ingress = true` in your terraform.tfvars  
**Documentation**: This file explains the changes and usage

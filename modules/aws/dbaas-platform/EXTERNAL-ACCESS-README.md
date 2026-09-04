# DBaaS External Access with ALB

This module provides external access to the DBaaS platform using an Application Load Balancer (ALB) managed by the AWS Load Balancer Controller.

## Configuration

Enable external access in your `terraform.tfvars`:

```hcl
# Enable ALB-based external access
enable_alb_ingress = true

# Cloudflare DNS configuration
enable_cloudflare_dns    = true
cloudflare_zone_id       = "your-zone-id"
cloudflare_api_token     = "your-api-token"  
cloudflare_proxy_enabled = false  # HTTP only initially
dbaas_domain_name        = "synxdb-elastic.synxdata.com"

# Service configuration
dbaas_namespace    = "dbaas"
dbaas_service_name = "dbaas-integration"
dbaas_service_port = 8030
```

## What Gets Deployed

1. **IAM Resources** - Policy and role for AWS Load Balancer Controller with OIDC trust
2. **AWS Load Balancer Controller** - Helm release in `kube-system` namespace
3. **Kubernetes Ingress** - Routes traffic to DBaaS service
4. **Application Load Balancer** - Automatically created by controller
5. **Cloudflare DNS** - CNAME record pointing to ALB

## Adding HTTPS (Optional)

1. Request ACM certificate:
```bash
aws acm request-certificate \
  --domain-name synxdb-elastic.synxdata.com \
  --validation-method DNS \
  --region us-west-2
```

2. Update `alb.tf` Ingress annotations:
```hcl
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:ACCOUNT:certificate/CERT_ID
alb.ingress.kubernetes.io/ssl-redirect: '443'
```

3. Enable Cloudflare proxy:
```hcl
cloudflare_proxy_enabled = true
```

## Files

- **`alb.tf`** - ALB configuration and AWS Load Balancer Controller
- **`cloudflare.tf`** - Cloudflare DNS management
- **`variables.tf`** - Configuration variables

## Outputs

- ALB hostname (from Ingress status)
- Cloudflare DNS record details
- IAM role ARN

## Troubleshooting

Check ALB creation:
```bash
kubectl describe ingress dbaas-ui-ingress -n dbaas
```

Check controller logs:
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

Verify ALB hostname:
```bash
kubectl get ingress dbaas-ui-ingress -n dbaas -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

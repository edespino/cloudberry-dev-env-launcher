# DBaaS External Access Setup Guide

This guide will help you set up external access to your DBaaS UI with static IPs and custom domain.

## Quick Start

### 1. Get Your Cloudflare Credentials

**Get Zone ID:**
1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Select your domain: `synxdata.com`
3. Copy the **Zone ID** from the right sidebar (under "API" section)

**Create API Token:**
1. Go to [API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token**
3. Use the **Edit zone DNS** template
4. Select Permissions:
   - Zone - Zone Settings - Read
   - Zone - DNS - Edit
5. Under **Zone Resources**, select your domain
6. Click **Continue to summary** → **Create Token**
7. Copy the token (you won't see it again!)

### 2. Set Environment Variable

```bash
export TF_VAR_cloudflare_api_token="your-cloudflare-api-token-here"
```

Or add to your shell profile (~/.bashrc, ~/.zshrc):
```bash
echo 'export TF_VAR_cloudflare_api_token="your-token"' >> ~/.zshrc
source ~/.zshrc
```

### 3. Create Configuration File

```bash
# Copy example configuration
cp external-access.tfvars.example external-access.tfvars

# Edit the file
nano external-access.tfvars
```

Update these values:
```hcl
enable_nlb_ingress       = true
dbaas_domain_name        = "synxdb-elastic.synxdata.com"  # Your domain
enable_cloudflare_dns    = true
cloudflare_zone_id       = "abc123def456"  # Your Zone ID
cloudflare_proxy_enabled = true
enable_ssl_redirect      = true
```

### 4. Update Main Configuration

Edit your `terraform.tfvars` to enable the dbaas-platform module:

```hcl
# Enable DBaaS platform deployment
deploy_dbaas_services = true
```

### 5. Apply Terraform

```bash
# Initialize (if providers changed)
terraform init

# Plan
terraform plan -var-file="external-access.tfvars"

# Apply
terraform apply -var-file="external-access.tfvars"
```

This will take approximately **10-15 minutes** to:
- Create 2 Elastic IPs
- Deploy NLB
- Install ingress-nginx controller
- Create ingress resources
- Configure Cloudflare DNS

### 6. Get Access URLs

After deployment completes:

```bash
# View outputs
terraform output

# Get specific URLs
terraform output dbaas_ui_url_https
terraform output dbaas_console_url_https
```

### 7. Access Your DBaaS UI

Open in browser:
- **Operations Dashboard**: `https://synxdb-elastic.synxdata.com/ops/`
- **User Console**: `https://synxdb-elastic.synxdata.com/console/user/login`

## Verification Steps

### Check DNS Resolution

```bash
dig synxdb-elastic.synxdata.com
```

Expected output:
```
synxdb-elastic.synxdata.com. 300 IN A 104.26.x.x  # Cloudflare IP
```

### Check NLB Status

```bash
kubectl get svc -n ingress-nginx
```

Expected output:
```
NAME                       TYPE           EXTERNAL-IP       PORT(S)
ingress-nginx-controller   LoadBalancer   xxx.elb.amazonaws.com   80:xxx/TCP,443:xxx/TCP
```

### Check Ingress

```bash
kubectl get ingress -n dbaas
```

Expected output:
```
NAME              CLASS   HOSTS                           ADDRESS
dbaas-ui-ingress  nginx   synxdb-elastic.synxdata.com     xxx.elb.amazonaws.com
```

### Test Access

```bash
# Test HTTP (will redirect to HTTPS if enabled)
curl -I http://synxdb-elastic.synxdata.com/ops/

# Test HTTPS
curl -I https://synxdb-elastic.synxdata.com/ops/
```

## Troubleshooting

### Issue: DNS not resolving

**Solution:**
```bash
# Check Cloudflare DNS records
terraform output cloudflare_dns_records

# Verify in Cloudflare dashboard
# DNS → Records → Look for your domain
```

### Issue: 502 Bad Gateway

**Cause:** Ingress controller or backend service not ready

**Solution:**
```bash
# Check ingress-nginx pods
kubectl get pods -n ingress-nginx

# Check DBaaS service
kubectl get pods -n dbaas

# Check service endpoints
kubectl get endpoints -n dbaas dbaas-integration
```

### Issue: 503 Service Unavailable

**Cause:** Backend service is not responding

**Solution:**
```bash
# Check DBaaS logs
kubectl logs -n dbaas -l app.kubernetes.io/name=synxdb-dbaas-integration

# Check service
kubectl describe svc -n dbaas dbaas-integration
```

### Issue: Cloudflare 525 Error

**Cause:** SSL handshake failed between Cloudflare and origin

**Solution:**
- Ensure `cloudflare_proxy_enabled = true`
- Use Cloudflare SSL mode: **Flexible** (in Cloudflare dashboard → SSL/TLS)
- Or configure TLS at ingress-nginx level with valid certificate

### Issue: Connection timeout

**Cause:** Security group or firewall blocking traffic

**Solution:**
```bash
# Check NLB security group
terraform output | grep security_group

# Verify nlb_allowed_cidrs includes your IP
```

## Security Best Practices

### 1. Restrict Access by IP

Update `external-access.tfvars`:
```hcl
nlb_allowed_cidrs = ["203.0.113.0/24"]  # Your office IP range
```

### 2. Enable Cloudflare Firewall

```hcl
enable_cloudflare_firewall = true
cloudflare_allowed_ips     = ["203.0.113.0/24"]
```

### 3. Monitor Access Logs

```bash
# Ingress-NGINX access logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100

# Cloudflare logs (requires Enterprise plan)
# Available in Cloudflare dashboard
```

## Updating Configuration

To change domain or settings:

```bash
# Edit configuration
nano external-access.tfvars

# Apply changes
terraform apply -var-file="external-access.tfvars"
```

## Disabling External Access

To remove external access while keeping EKS cluster:

```bash
# Edit external-access.tfvars
enable_nlb_ingress = false

# Apply
terraform apply -var-file="external-access.tfvars"
```

This will remove:
- Elastic IPs
- NLB
- Ingress-NGINX controller
- Cloudflare DNS records

But keeps:
- EKS cluster
- DBaaS application
- RDS database
- S3 buckets

## Cost Impact

**Additional Monthly Costs:**
- Network Load Balancer: ~$18/month
- Elastic IPs (2): Free when attached to NLB
- Data transfer: Variable (typically $0.09/GB out)
- Cloudflare: Free tier (includes SSL + DDoS)

**Estimated Total: ~$20-30/month** (excluding data transfer)

## Next Steps

1. ✅ Set up monitoring and alerting
2. ✅ Configure backup and disaster recovery
3. ✅ Implement CI/CD pipeline for DBaaS deployments
4. ✅ Set up log aggregation (e.g., CloudWatch, ELK)
5. ✅ Configure auto-scaling for EKS nodes
6. ✅ Implement network policies for pod-to-pod security

## Support

For issues or questions:
1. Check the main [EXTERNAL-ACCESS.md](../../../modules/aws/dbaas-platform/EXTERNAL-ACCESS.md) documentation
2. Review Terraform state: `terraform show`
3. Check logs: `kubectl logs -n <namespace> <pod-name>`
4. Contact your DevOps team

---

**Created**: 2025-11-13
**Environment**: rl9-synx-elastic
**Module Version**: dbaas-platform v1.0

# Troubleshooting

Common issues and solutions for the Cloudberry Development Environment Launcher.

## Setup Issues

### Prerequisites Not Met

**Error:** `command not found: terraform` or similar
**Solution:** Install missing prerequisites following [PREREQUISITES.md](PREREQUISITES.md)

```bash
# Check what's missing
terraform version  # Should show >= 1.0
aws --version      # Should show AWS CLI v2
direnv version     # Should show direnv
jq --version       # Should show jq
```

### AWS Configuration Issues

**Error:** `Unable to locate credentials`
**Solution:** Configure AWS SSO
```bash
aws configure sso
aws sso login --sso-session your-sso-session
```

**Error:** `Access Denied` for S3/DynamoDB
**Solution:** Verify backend resources exist
```bash
# Check S3 bucket
aws s3 ls s3://your-terraform-state-bucket/

# Check DynamoDB table
aws dynamodb describe-table --table-name terraform-lock --region us-west-2
```

## Environment Loading Issues

### direnv Not Working

**Error:** Environment variables not loaded when entering directory
**Solutions:**
```bash
# 1. Allow the environment
direnv allow .

# 2. If still not working, check direnv installation
direnv version

# 3. Verify shell integration
echo $SHELL
# Add to ~/.zshrc or ~/.bashrc:
eval "$(direnv hook zsh)"  # or bash

# 4. Source manually as fallback
source .envrc
```

### AMI Discovery Failures

**Error:** `No AMI found matching specified criteria`
**Diagnosis:**
```bash
# Test AMI query manually
AMI_OWNER="679593333241"
AMI_FILTER="cloudimg-oel810-lvm-*"
aws ec2 describe-images --region us-west-2 \
  --owners $AMI_OWNER \
  --filters "Name=name,Values=$AMI_FILTER" \
  --query 'Images[*].[Name,ImageId,CreationDate]' \
  --output table
```

**Solutions:**
1. **Check region**: AMIs are region-specific
2. **Verify owner ID**: Ensure `AMI_OWNER` is correct
3. **Update filter**: Adjust `AMI_FILTER` pattern
4. **Check permissions**: Ensure EC2 `DescribeImages` permission

## Terraform Issues

### Backend Initialization Failures

**Error:** `Error loading backend`
**Solutions:**

**For Local Backend (default):**
```bash
# 1. Remove corrupted state and re-initialize
rm -rf .terraform
terraform init

# 2. If state file is corrupted, restore from backup
cp terraform.tfstate.backup terraform.tfstate
```

**For S3 Backend (using tis3 alias):**
```bash
# 1. Verify S3 bucket exists and is accessible
aws s3 ls s3://your-terraform-state-bucket/

# 2. Check AWS credentials
aws sts get-caller-identity

# 3. Retry S3 initialization
tis3

# 4. Switch back to local backend if needed
ti
```

**For S3 Backend (configured in backend.tf):**
```bash
# 1. Verify S3 bucket and reconfigure
terraform init -reconfigure

# 2. Migrate back to local if needed
terraform init -migrate-state
```

### State Lock Issues

**Error:** `Error acquiring the state lock`

**For Local Backend:**
- Local backend doesn't support locking
- Ensure only one `terraform` command runs at a time
- Kill any stuck terraform processes: `pkill terraform`

**For S3 Backend:**
```bash
# 1. Wait for other operations to complete
# 2. If stuck, force unlock (use carefully)
terraform force-unlock <LOCK_ID>

# 3. Check DynamoDB table exists
aws dynamodb describe-table --table-name terraform-lock --region us-west-2
```

### Resource Creation Failures

**Error:** `UnauthorizedOperation` or `AccessDenied`
**Solution:** Check IAM permissions
```bash
# Verify your AWS identity
aws sts get-caller-identity

# Test specific permissions
aws ec2 describe-instances --region us-west-2
aws iam list-roles
```

## Instance Issues

### SSH Connection Refused

**Error:** `Connection refused` or `Connection timed out`
**Diagnosis:**
```bash
# 1. Check instance state
istate

# 2. Verify instance is running
aws ec2 describe-instances --region us-west-2 \
  --filters "Name=tag:Name,Values=${TF_VAR_env_prefix}-instance-0" \
  --query 'Reservations[*].Instances[*].[State.Name,PublicIpAddress]'

# 3. Test connectivity
nc -zv <INSTANCE_IP> 22
```

**Solutions:**
1. **Wait for instance**: Use `lw` to wait for SSH readiness
2. **Check security groups**: Ensure your IP is allowed
3. **Verify SSH key**: Ensure correct key file and permissions
4. **Check instance status**: Instance might be still launching

### Instance Won't Start

**Error:** Instance stuck in `pending` state
**Solutions:**
```bash
# 1. Check instance status checks
aws ec2 describe-instance-status --region us-west-2 \
  --instance-ids <INSTANCE_ID>

# 2. Check for capacity issues (common with spot instances)
aws ec2 describe-spot-instance-requests --region us-west-2

# 3. Try different instance type or availability zone
# Edit .envrc and change TF_VAR_instance_type
```

### Spot Instance Interruptions

**Error:** Instance terminated unexpectedly
**Solutions:**
```bash
# 1. Check spot instance status
aws ec2 describe-spot-instance-requests --region us-west-2

# 2. Redeploy if needed
terraform apply

# 3. Consider mixed instance strategy
export TF_VAR_spot_instance_strategy="mixed"

# 4. Use on-demand for critical workloads
export TF_VAR_use_spot_instances="false"
```

## Cost Issues

### Unexpected High Costs

**Diagnosis:**
```bash
# 1. Check running instances
iastate  # All instances across regions

# 2. Check for forgotten resources
aws ec2 describe-instances --region us-west-2 \
  --query 'Reservations[*].Instances[?State.Name!=`terminated`].[Tags[?Key==`Name`].Value|[0],State.Name,InstanceType]'

# 3. Review AWS Cost Explorer
```

**Solutions:**
1. **Stop unused instances**: `istop`
2. **Destroy old environments**: `terraform destroy`
3. **Use spot instances**: `export TF_VAR_use_spot_instances="true"`
4. **Right-size instances**: Start with smaller instance types

## Monitoring Issues

### CloudWatch Alarms Not Working

**Error:** No alert emails received
**Solutions:**
```bash
# 1. Verify SES email address
aws ses get-identity-verification-attributes \
  --identities your-email@company.com --region us-west-2

# 2. Check SNS subscription
aws sns list-subscriptions --region us-west-2

# 3. Test Lambda function
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda" --region us-west-2
```

### Missing Metrics

**Error:** No CloudWatch metrics showing
**Solutions:**
1. **Enable detailed monitoring**: `export TF_VAR_enable_monitoring="true"`
2. **Wait for metrics**: Can take 5-15 minutes to appear
3. **Check CloudWatch agent**: SSH to instance and check agent status

## Development Issues

### VS Code Remote Not Working

**Error:** Cannot connect VS Code to remote instance
**Solutions:**
```bash
# 1. Ensure SSH works first
lssh

# 2. Check VS Code Remote SSH extension installed
# 3. Use the icode alias
icode

# 4. Manual VS Code remote connection
code --remote ssh-remote+${TF_VAR_env_prefix} /home/gpadmin
```

### File Transfer Issues

**Error:** `scp` or `rsync` failures
**Solutions:**
```bash
# 1. Test basic SSH first
lssh

# 2. Use built-in aliases
lcopyto /local/file /remote/path
lcopyfrom /remote/path /local/file

# 3. Check file permissions
ls -la ~/.ssh/${SSH_KEY_PATH}  # Should be 400
```

## Performance Issues

### Slow Instance Performance

**Diagnosis:**
```bash
# Check system resources
itop    # htop on remote instance
idisk   # disk usage
ilogs   # system logs
```

**Solutions:**
1. **Upgrade instance type**: Edit `TF_VAR_instance_type` in `.envrc`
2. **Optimize disk**: Increase IOPS/throughput in `.envrc`
3. **Check placement groups**: Ensure instances in same placement group
4. **Monitor network**: Check for bandwidth limitations

## Getting Additional Help

### Collect Debug Information

Before asking for help, collect this information:

```bash
# Environment info
iinfo

# System versions
terraform version
aws --version
direnv version

# AWS configuration
aws sts get-caller-identity
aws configure list

# Instance status
istate

# Recent Terraform logs
terraform show
```

### Where to Get Help

1. **Documentation**: Check all guides in `docs/` directory
2. **AWS Docs**: [AWS Terraform Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
3. **Community**: Open GitHub issue with debug information
4. **AWS Support**: For AWS-specific issues

### Reporting Issues

When reporting issues, include:
- **Environment**: OS, tool versions
- **Configuration**: Relevant `.envrc` settings (sanitized)
- **Error messages**: Full error text
- **Steps to reproduce**: What you were trying to do
- **Debug output**: From the debug collection above

## Emergency Procedures

### Complete Environment Reset

If everything is broken:
```bash
# 1. Destroy infrastructure
terraform destroy

# 2. Clean local state
rm -rf .terraform
rm -f terraform.tfstate*
rm -f *.pem

# 3. Start fresh
terraform init
terraform plan
terraform apply
```

### Cost Emergency Stop

If costs are running away:
```bash
# 1. Stop all instances immediately
istop

# 2. Or destroy everything
terraform destroy

# 3. Check AWS console for any remaining resources
```

Remember: **When in doubt, destroy and recreate**. The infrastructure is designed to be ephemeral and reproducible!
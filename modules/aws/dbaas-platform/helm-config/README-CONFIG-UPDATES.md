# DBaaS Configuration Management

This directory contains scripts to manage the DBaaS configuration with credentials from Terraform-managed infrastructure.

## Overview

The `update-dbaas-config.sh` script automatically extracts credentials and configuration from Terraform state and updates the `dbaas-values.yaml` file with:

- **RDS PostgreSQL credentials** (JDBC URL, username, password)
- **IAM user credentials** (Access Key ID, Secret Access Key)
- **S3 bucket names** (storage and backup buckets)

## Usage

### Running the Update Script

```bash
# From the environment directory (rl9-elastic)
./example/update-dbaas-config.sh
```

The script will:
1. Extract all credentials from Terraform state
2. Create a timestamped backup of the current values file
3. Update `dbaas-values.yaml` with the new credentials
4. Display a summary of changes

### What Gets Updated

The script updates the following sections in `dbaas-values.yaml`:

#### 1. RDS PostgreSQL Configuration
```yaml
spring:
  datasource:
    url: jdbc:postgresql://[ENDPOINT]:5432/dbaas
    username: dbaasadmin
    password: "[AUTO-GENERATED]"
    driver-class-name: org.postgresql.Driver
```

#### 2. IAM Credentials for S3 Access
```yaml
dbaas:
  region:
    oss:
      us:
        access-key-id: "AKIA..."
        access-key-secret: "[AUTO-GENERATED]"
```

#### 3. S3 Bucket References (in comments)
```yaml
# S3 Storage Bucket: [BUCKET-NAME]
# S3 Backup Bucket: [BUCKET-NAME]
```

#### 4. AWS Account ID in ECR Image References

The committed values files carry `<AWS_ACCOUNT_ID>` in every ECR registry host
(`<AWS_ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/...`). The script replaces it
with the deploying account from `aws sts get-caller-identity`, in
`dbaas-values.yaml`, `foundationdb-values.yaml`, and `cloudbeaver-values.yaml`. The RDS endpoint and master
password are likewise committed as `RDS_ENDPOINT` / `CHANGE_ME` and filled from
Terraform state; never commit the filled files.

## Security Considerations

⚠️ **IMPORTANT SECURITY WARNINGS:**

1. **Never commit credentials**: The `dbaas-values.yaml` file contains sensitive credentials
2. **Backup files**: The script creates timestamped backups with credentials - keep these secure
3. **Credential rotation**: Re-run the script after rotating credentials in Terraform
4. **Access control**: Restrict access to this file and backups

### Recommended Practices

1. **Use .gitignore**: Ensure `dbaas-values.yaml` is in `.gitignore`
   ```bash
   echo "example/dbaas-values.yaml" >> .gitignore
   echo "example/dbaas-values.yaml.backup.*" >> .gitignore
   ```

2. **Kubernetes Secrets**: For production, consider using Kubernetes secrets:
   ```bash
   kubectl create secret generic dbaas-rds-credentials \
     --from-literal=username=dbaasadmin \
     --from-literal=password='...' \
     -n dbaas

   kubectl create secret generic dbaas-s3-credentials \
     --from-literal=access-key-id='...' \
     --from-literal=secret-access-key='...' \
     -n dbaas
   ```

3. **AWS Secrets Manager**: RDS password is also stored in AWS Secrets Manager:
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id eespino-synx-rl9-elastic-dbaas-rds-credentials-x8Qjy5 \
     --region us-west-2
   ```

## Prerequisites

The script requires:
- **jq**: JSON processor (`brew install jq` on macOS)
- **Terraform state**: Must have run `terraform apply` successfully
- **Bash**: Version 4.0 or later

## Troubleshooting

### Error: "terraform.tfstate not found"
**Solution**: Run `terraform apply` to create the infrastructure first.

### Error: "Failed to extract [credential] from Terraform state"
**Solution**:
1. Verify Terraform deployment succeeded: `terraform plan`
2. Check that `deploy_dbaas_services = true` in your Terraform variables
3. Ensure the dbaas_platform module was applied successfully

### Credentials not working after update
**Solution**:
1. Verify Terraform state is current: `terraform refresh`
2. Re-run the update script
3. Check AWS console that IAM user and RDS instance exist

## Manual Verification

After running the script, verify the configuration:

```bash
# Check RDS connectivity
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- \
  psql "postgresql://dbaasadmin:PASSWORD@ENDPOINT:5432/dbaas"

# Check S3 access with IAM credentials
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
aws s3 ls s3://eespino-synx-rl9-elastic-dbaas-storage-ae97420f/
```

## Related Documentation

- [synx-elastic-s3-CLAUDE.md](../synx-elastic-s3-CLAUDE.md) - Complete migration guide
- [Terraform outputs](../outputs.tf) - Available Terraform outputs
- [DBaaS Platform Module](../../../../modules/aws/dbaas-platform/) - Infrastructure definition

## Workflow

### Initial Setup
1. Deploy infrastructure: `terraform apply`
2. Update configuration: `./example/update-dbaas-config.sh`
3. Deploy DBaaS: `helm install dbaas-integration helm/synxdb-dbaas-integration-*.tgz --namespace dbaas -f example/dbaas-values.yaml`

### After Infrastructure Changes
1. Update infrastructure: `terraform apply`
2. Update configuration: `./example/update-dbaas-config.sh`
3. Upgrade DBaaS: `helm upgrade dbaas-integration helm/synxdb-dbaas-integration-*.tgz --namespace dbaas -f example/dbaas-values.yaml`

### Credential Rotation
1. Rotate in Terraform: `terraform apply -replace='module.dbaas_platform[0].aws_iam_access_key.dbaas_s3_user_key[0]'`
2. Update configuration: `./example/update-dbaas-config.sh`
3. Restart DBaaS: `kubectl rollout restart deployment/dbaas-integration -n dbaas`

## Files

- `update-dbaas-config.sh` - Main update script
- `dbaas-values.yaml` - Helm values file (DO NOT COMMIT)
- `dbaas-values.yaml.backup.*` - Timestamped backups (DO NOT COMMIT)
- `populate-rds-credentials.sh` - Legacy script (deprecated, use update-dbaas-config.sh instead)

## Support

For issues or questions:
1. Review the [synx-elastic-s3-CLAUDE.md](../synx-elastic-s3-CLAUDE.md) troubleshooting section
2. Check Terraform state: `terraform show`
3. Verify AWS resources exist in the console

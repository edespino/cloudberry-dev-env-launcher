#!/bin/bash
# Script to update dbaas-values.yaml with Terraform-generated credentials
# This script extracts RDS and IAM credentials from Terraform state and updates the values file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VALUES_FILE="${SCRIPT_DIR}/dbaas-values.yaml"
BACKUP_FILE="${VALUES_FILE}.backup.$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "DBaaS Configuration Update Script"
echo "========================================"
echo ""
echo "Working directory: ${TERRAFORM_DIR}"
echo "Values file: ${VALUES_FILE}"
echo ""

# Change to Terraform directory
cd "${TERRAFORM_DIR}"

# Verify Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo "ERROR: terraform.tfstate not found in ${TERRAFORM_DIR}"
    echo "Please run 'terraform apply' first to create the infrastructure"
    exit 1
fi

echo "Step 1: Extracting RDS credentials from Terraform state..."
echo "-----------------------------------------------------------"

# Extract RDS credentials
RDS_JDBC_URL=$(terraform state pull | jq -r '.outputs.dbaas_platform_summary.value.rds_database.jdbc_url')
RDS_USERNAME=$(terraform state pull | jq -r '.outputs.dbaas_platform_summary.value.rds_database.username')
RDS_PASSWORD=$(terraform state pull | jq -r '.resources[] | select(.type == "random_password" and .name == "rds_master_password") | .instances[0].attributes.result')

if [ -z "$RDS_JDBC_URL" ] || [ "$RDS_JDBC_URL" = "null" ]; then
    echo "ERROR: Failed to extract RDS JDBC URL from Terraform state"
    exit 1
fi

if [ -z "$RDS_PASSWORD" ] || [ "$RDS_PASSWORD" = "null" ]; then
    echo "ERROR: Failed to extract RDS password from Terraform state"
    exit 1
fi

echo "✓ RDS JDBC URL: ${RDS_JDBC_URL}"
echo "✓ RDS Username: ${RDS_USERNAME}"
echo "✓ RDS Password: [REDACTED - ${#RDS_PASSWORD} characters]"
echo ""

echo "Step 2: Extracting S3 bucket names..."
echo "-----------------------------------------------------------"

# Extract S3 bucket names
S3_STORAGE_BUCKET=$(terraform state pull | jq -r '.outputs.dbaas_platform_summary.value.s3_buckets.storage_bucket')
S3_BACKUP_BUCKET=$(terraform state pull | jq -r '.outputs.dbaas_platform_summary.value.s3_buckets.backup_bucket')

if [ -z "$S3_STORAGE_BUCKET" ] || [ "$S3_STORAGE_BUCKET" = "null" ]; then
    echo "ERROR: Failed to extract S3 storage bucket from Terraform state"
    exit 1
fi

echo "✓ S3 Storage Bucket: ${S3_STORAGE_BUCKET}"
echo "✓ S3 Backup Bucket: ${S3_BACKUP_BUCKET}"
echo ""

echo "Step 3: Extracting IAM user credentials..."
echo "-----------------------------------------------------------"

# Extract IAM user credentials
IAM_ACCESS_KEY_ID=$(terraform state pull | jq -r '.resources[] | select(.type == "aws_iam_access_key" and .name == "dbaas_s3_user_key") | .instances[0].attributes.id')
IAM_SECRET_KEY=$(terraform state pull | jq -r '.resources[] | select(.type == "aws_iam_access_key" and .name == "dbaas_s3_user_key") | .instances[0].attributes.secret')

if [ -z "$IAM_ACCESS_KEY_ID" ] || [ "$IAM_ACCESS_KEY_ID" = "null" ]; then
    echo "ERROR: Failed to extract IAM access key ID from Terraform state"
    exit 1
fi

if [ -z "$IAM_SECRET_KEY" ] || [ "$IAM_SECRET_KEY" = "null" ]; then
    echo "ERROR: Failed to extract IAM secret key from Terraform state"
    exit 1
fi

echo "✓ IAM Access Key ID: ${IAM_ACCESS_KEY_ID}"
echo "✓ IAM Secret Key: [REDACTED - ${#IAM_SECRET_KEY} characters]"
echo ""

echo "Step 4: Creating backup of current values file..."
echo "-----------------------------------------------------------"

# Backup existing file
cp "${VALUES_FILE}" "${BACKUP_FILE}"
echo "✓ Backup created: ${BACKUP_FILE}"
echo ""

echo "Step 5: Updating dbaas-values.yaml..."
echo "-----------------------------------------------------------"

# Function to escape special characters for sed
escape_for_sed() {
    echo "$1" | sed 's/[&/\]/\\&/g' | sed 's/\$/\\$/g' | sed 's/\[/\\[/g' | sed 's/\]/\\]/g'
}

# Escape values
RDS_JDBC_URL_ESCAPED=$(escape_for_sed "$RDS_JDBC_URL")
RDS_USERNAME_ESCAPED=$(escape_for_sed "$RDS_USERNAME")
RDS_PASSWORD_ESCAPED=$(escape_for_sed "$RDS_PASSWORD")
S3_STORAGE_BUCKET_ESCAPED=$(escape_for_sed "$S3_STORAGE_BUCKET")
S3_BACKUP_BUCKET_ESCAPED=$(escape_for_sed "$S3_BACKUP_BUCKET")
IAM_ACCESS_KEY_ID_ESCAPED=$(escape_for_sed "$IAM_ACCESS_KEY_ID")
IAM_SECRET_KEY_ESCAPED=$(escape_for_sed "$IAM_SECRET_KEY")

# Create temporary file for sed operations
TEMP_FILE="${VALUES_FILE}.tmp"
cp "${VALUES_FILE}" "${TEMP_FILE}"

# Update RDS JDBC URL (extract just the endpoint from the URL for the url field)
sed -i.bak "/datasource:/,/driver-class-name:/ {
    s|url: jdbc:postgresql://[^/]*/dbaas|url: ${RDS_JDBC_URL_ESCAPED}|
}" "${TEMP_FILE}"

# Update RDS username
sed -i.bak "/datasource:/,/driver-class-name:/ {
    s|username: .*|username: ${RDS_USERNAME_ESCAPED}|
}" "${TEMP_FILE}"

# Update RDS password
sed -i.bak "/datasource:/,/driver-class-name:/ {
    s|password: \".*\"|password: \"${RDS_PASSWORD_ESCAPED}\"|
}" "${TEMP_FILE}"

# Update IAM credentials (look for the access-key-id and access-key-secret in oss section)
sed -i.bak "/oss:/,/specs:/ {
    s|access-key-id: \".*\"|access-key-id: \"${IAM_ACCESS_KEY_ID_ESCAPED}\"|
    s|access-key-secret: \".*\"|access-key-secret: \"${IAM_SECRET_KEY_ESCAPED}\"|
}" "${TEMP_FILE}"

# Update S3 bucket comments
sed -i.bak "s|# S3 Storage Bucket: .*|# S3 Storage Bucket: ${S3_STORAGE_BUCKET_ESCAPED}|" "${TEMP_FILE}"
sed -i.bak "s|# S3 Backup Bucket: .*|# S3 Backup Bucket: ${S3_BACKUP_BUCKET_ESCAPED}|" "${TEMP_FILE}"

# Fill the AWS account ID in ECR image references (committed files carry the
# <AWS_ACCOUNT_ID> placeholder; the registry lives in the deploying account).
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)
if [ -n "${AWS_ACCOUNT_ID}" ] && [ "${AWS_ACCOUNT_ID}" != "None" ]; then
    sed -i.bak "s|<AWS_ACCOUNT_ID>|${AWS_ACCOUNT_ID}|g" "${TEMP_FILE}"
    for extra in foundationdb-values.yaml cloudbeaver-values.yaml; do
        if grep -q '<AWS_ACCOUNT_ID>' "${SCRIPT_DIR}/${extra}"; then
            sed -i.bak "s|<AWS_ACCOUNT_ID>|${AWS_ACCOUNT_ID}|g" "${SCRIPT_DIR}/${extra}"
            rm -f "${SCRIPT_DIR}/${extra}.bak"
        fi
    done
    echo "✓ Filled AWS account ID in ECR image references"
else
    echo "WARNING: could not determine the AWS account ID; <AWS_ACCOUNT_ID> placeholders left in place"
fi

# Remove backup files created by sed
rm -f "${TEMP_FILE}.bak"

# Move temp file to final location
mv "${TEMP_FILE}" "${VALUES_FILE}"

echo "✓ Updated RDS configuration"
echo "✓ Updated IAM credentials"
echo "✓ Updated S3 bucket references"
echo ""

echo "========================================"
echo "Configuration Update Complete!"
echo "========================================"
echo ""
echo "Summary of changes:"
echo "  - RDS Endpoint: Updated to current Terraform-managed instance"
echo "  - RDS Password: Updated from Terraform state"
echo "  - IAM Credentials: Updated from Terraform state"
echo "  - S3 Buckets: ${S3_STORAGE_BUCKET} / ${S3_BACKUP_BUCKET}"
echo ""
echo "⚠️  SECURITY WARNING:"
echo "  - The values file contains sensitive credentials"
echo "  - DO NOT commit ${VALUES_FILE} to version control"
echo "  - Backup saved to: ${BACKUP_FILE}"
echo ""
echo "Next steps:"
echo "  1. Review the updated file: cat ${VALUES_FILE}"
echo "  2. Deploy with: helm upgrade --install dbaas-integration helm/synxdb-dbaas-integration-*.tgz --namespace dbaas -f ${VALUES_FILE}"
echo ""

# DBaaS Module Conditional Loading Fix

> Status: applied. `module "dbaas_platform"` in `environments/multi-os-sample/main.tf` carries
> `count = var.deploy_dbaas_services ? 1 : 0`. Kept as a record of the November 2025 investigation.

## Issue Summary

**Problem:** Newly created environments showed "UNKNOWN" status for Spot Instances, SSH Access, and Monitoring in the `.envrc` display, regardless of whether DBaaS platform was selected or not.

**Date:** November 18, 2025

## Root Cause Analysis

### Primary Issue
The `.envrc` file uses `terraform console` to query variable values for status display:
```bash
spot_value=$(echo "var.use_spot_instances" | terraform console 2>/dev/null ...)
```

However, `terraform console` was failing with this error:
```
Error: Missing required argument
  on main.tf line 100, in module "dbaas_platform":
 100: module "dbaas_platform" {

The argument "internet_gateway_id" is required, but no definition was found.
```

### Secondary Issues

1. **Missing Parameter**: The `internet_gateway_id` parameter was added to the `dbaas-platform` module but not passed from the environment's `main.tf`

2. **Template Design Flaw**: The `multi-os-sample` template included the `dbaas_platform` module block with `count` conditional, but Terraform validates module arguments even when `count = 0`, causing validation errors for non-DBaaS environments

3. **Hanging Data Source**: The original implementation used a data source to look up the Internet Gateway, which would hang indefinitely during `terraform apply` operations

## Solution Implementation

### 1. Fix Internet Gateway Dependency (Primary Fix)

**Problem:** Data source hanging during terraform apply
**Solution:** Pass IGW ID directly through module outputs/inputs

**Files Changed:**
- `modules/aws/database-cluster/outputs.tf`: Added `internet_gateway_id` output
- `modules/aws/dbaas-platform/variables.tf`: Added `internet_gateway_id` variable
- `modules/aws/dbaas-platform/networking.tf`: Replaced data source with variable reference
- All environment `main.tf` files: Pass `internet_gateway_id` from database_cluster to dbaas_platform

**Before:**
```hcl
# dbaas-platform/networking.tf
data "aws_internet_gateway" "main" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}
```

**After:**
```hcl
# database-cluster/outputs.tf
output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

# environment/main.tf
module "dbaas_platform" {
  ...
  internet_gateway_id = module.database_cluster.internet_gateway_id
}
```

### 2. Make DBaaS Module Conditional (Secondary Fix)

**Problem:** Template includes dbaas_platform module that causes validation errors for non-DBaaS environments
**Solution:** Remove module from template, add it dynamically via os-selector

**Files Changed:**
- `environments/multi-os-sample/main.tf`: Removed `dbaas_platform` module block
- `bin/os-selector`: Added logic to append module block only when `deploy_dbaas=true`

**Implementation in os-selector:**
```bash
if [[ "$deploy_dbaas" == "true" ]]; then
    # Append DBaaS platform module to main.tf
    cat >> "$target_dir/main.tf" << 'DBAAS_MODULE_EOF'

# DBaaS Platform Module (optional EKS + S3 infrastructure)
module "dbaas_platform" {
  count  = var.deploy_dbaas_services ? 1 : 0
  source = "../../../modules/aws/dbaas-platform"

  # Core Configuration (from database cluster)
  region               = var.region
  env_prefix           = var.env_prefix
  vpc_id               = module.database_cluster.vpc_id
  public_subnet_id     = module.database_cluster.subnet_id
  internet_gateway_id  = module.database_cluster.internet_gateway_id

  # ... rest of configuration
}
DBAAS_MODULE_EOF
fi
```

## Testing Procedure

### Test Case 1: Non-DBaaS Environment
1. Run: `bin/os-selector`
2. Select an OS (e.g., Rocky Linux 9)
3. When prompted for DBaaS platform, select "No"
4. Verify created environment:
   - `main.tf` should NOT contain `dbaas_platform` module block
   - `.envrc` should show proper status (not UNKNOWN)
   - `terraform console` should work without errors

### Test Case 2: DBaaS Environment
1. Run: `bin/os-selector`
2. Select an OS
3. When prompted for DBaaS platform, select "Yes"
4. Verify created environment:
   - `main.tf` SHOULD contain `dbaas_platform` module block
   - Module block includes `internet_gateway_id` parameter
   - `.envrc` should show proper status
   - `terraform console` should work without errors
   - `terraform apply` should not hang on IGW lookup

## Files Modified

### Core Infrastructure
- `modules/aws/database-cluster/outputs.tf` - Added IGW output
- `modules/aws/dbaas-platform/variables.tf` - Added IGW variable
- `modules/aws/dbaas-platform/networking.tf` - Replaced data source with variable

### Templates and Tools
- `environments/multi-os-sample/main.tf` - Removed dbaas_platform module
- `bin/os-selector` - Added conditional module injection

### Existing Environments (Manual Updates Required)
All existing environments with DBaaS platform need manual update:
- Add `internet_gateway_id = module.database_cluster.internet_gateway_id` to dbaas_platform module call

OR simply recreate environments using updated os-selector.

## Migration Guide for Existing Environments

### Option 1: Recreate (Recommended)
```bash
# Destroy old environment
cd environments/synx/<env-name>
terraform destroy

# Remove directory
cd ..
rm -rf <env-name>

# Recreate with os-selector
cd ../../..
bin/os-selector
```

### Option 2: Manual Update
For environments with DBaaS platform:
```hcl
# Edit main.tf, find dbaas_platform module, add:
  internet_gateway_id  = module.database_cluster.internet_gateway_id
```

For non-DBaaS environments:
```bash
# Remove entire dbaas_platform module block from main.tf
# From line "# DBaaS Platform Module..." to closing "}"
```

## Related Issues

### Original IGW Hanging Issue
This fix also resolves the original issue where Terraform would hang during apply:
```
module.dbaas_platform[0].data.aws_internet_gateway.main: Still reading... [23m40s elapsed]
```

The data source would wait indefinitely because it was evaluated before the IGW was created by the database_cluster module, creating a timing issue.

### Terraform Console Validation Behavior
Terraform validates all module blocks during the console initialization phase, even if `count = 0`. This means:
- Modules with `count` conditionals still require valid arguments
- Having optional modules in templates causes issues for environments that don't use them
- Best practice: Add optional modules dynamically rather than using count conditionals in templates

## Prevention

### For Future Module Updates
1. **Always test both configurations**: When modifying shared modules, test with DBaaS enabled AND disabled
2. **Update templates**: When adding required parameters, update both the module AND all calling environments
3. **Document breaking changes**: New required parameters are breaking changes and should be documented

### For New Environments
1. **Use os-selector**: Always create new environments via `bin/os-selector` to ensure proper configuration
2. **Don't copy/paste**: Avoid manually copying environment directories, as they may have outdated configurations

## References

- **Commit**: "Fix Internet Gateway dependency and add external access support"
- **Related Files**: See commit for complete list of modified files
- **Discussion**: Session dated November 18, 2025

## Verification Checklist

- [ ] Non-DBaaS environment created successfully
- [ ] Non-DBaaS environment shows proper status in .envrc (no UNKNOWN)
- [ ] DBaaS environment created successfully
- [ ] DBaaS environment includes internet_gateway_id parameter
- [ ] terraform console works in both environment types
- [ ] terraform apply completes without hanging
- [ ] All existing DBaaS environments updated or recreated

## Notes

- This issue only affected environments created AFTER the dbaas-platform module was updated with the internet_gateway_id requirement
- Existing deployed environments are unaffected until they run `terraform apply` with the updated configuration
- The .envrc UNKNOWN status was a symptom, not the root cause

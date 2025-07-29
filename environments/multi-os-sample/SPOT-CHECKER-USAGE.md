# Spot Instance Availability Checker

This environment includes comprehensive spot instance availability checking tools to help you avoid hanging Terraform applies.

## 🚀 Quick Start

```bash
# Check if spot instances are available before launching
./spot-check

# Quick price overview only
./spot-check prices
```

**Alternative (for advanced users):**
```bash
# Source functions if you want to customize or integrate
source .env && check_spot_availability
source .env && check_spot_prices
```

## 📋 Available Commands

### `spot-check` (Comprehensive Analysis)
**Full command:** `check_spot_availability`

Provides detailed analysis including:
- ✅ Current spot prices across all availability zones
- 📋 Recent spot instance request history (last 2 hours)
- 🧪 Dry-run validation of spot requests
- 🎯 Specific recommendations for your configuration
- 🔧 Current environment settings

**Example output:**
```
🔍 Checking spot availability for c7i.4xlarge in us-west-2...
📊 Max price budget: $0.50/hour

💰 Current spot prices across availability zones:
  ✅ us-west-2c: $0.329200 (within budget)
  ✅ us-west-2b: $0.315100 (within budget)
  ✅ us-west-2a: $0.333200 (within budget)

🎯 Recommendations:
  ✅ Spot instances look viable
  🎯 Best AZs to try: us-west-2c us-west-2b us-west-2a
```

### `spot-prices` (Quick Price Check)
**Full command:** `check_spot_prices`

Shows current spot pricing in table format:
```
💰 Current spot prices for c7i.4xlarge:
+-------------+------------+
|  us-west-2c |  0.329200  |
|  us-west-2b |  0.315100  |
|  us-west-2a |  0.333200  |
+-------------+------------+
📊 Your max price: $0.50/hour
```

## 🔧 Configuration

The checker uses these environment variables (defined in `.envrc`):

```bash
export TF_VAR_instance_type="c7i.4xlarge"      # Instance type to check
export TF_VAR_region="us-west-2"               # AWS region
export TF_VAR_spot_max_price="0.50"            # Max price budget
export TF_VAR_use_spot_instances="false"       # Current spot setting
export TF_VAR_ami="ami-0c2f628a90a79bff4"      # AMI for validation
```

## 🎯 Usage Workflow

### Before Launching Infrastructure

1. **Check spot availability:**
   ```bash
   ./spot-check
   ```

2. **Interpret results:**
   - ✅ **Green prices within budget** → Safe to use spot instances
   - ❌ **Red prices exceeding budget** → Consider on-demand or smaller instance
   - ⚠️ **Recent capacity issues** → May want to avoid spot instances

3. **Adjust configuration if needed:**
   ```bash
   # Enable/disable spot instances
   export TF_VAR_use_spot_instances="true"   # or "false"
   
   # Adjust max price if needed
   export TF_VAR_spot_max_price="0.75"      # increase budget
   
   # Try smaller instance type if prices too high
   export TF_VAR_instance_type="c7i.2xlarge"
   ```

4. **Run Terraform:**
   ```bash
   terraform apply
   ```

### When Terraform Hangs

If `terraform apply` hangs on instance creation:

1. **Cancel the operation:**
   ```bash
   Ctrl+C
   ```

2. **Check current spot status:**
   ```bash
   ./spot-check
   ```

3. **Switch to on-demand temporarily:**
   ```bash
   export TF_VAR_use_spot_instances="false"
   terraform apply
   ```

4. **Try again later with spot instances when capacity improves**

## 📊 Understanding the Output

### Spot Price Status Icons
- ✅ **Within budget** - Price below your max price
- ❌ **Exceeds budget** - Price above your max price
- ⏳ **Pending** - Spot requests in progress
- 🚫 **Cancelled** - Recent requests cancelled
- ⚠️ **Capacity issues** - Limited availability

### Common Status Codes
- `fulfilled` - Spot request succeeded ✅
- `capacity-not-available` - No spot capacity ❌
- `price-too-low` - Your max price too low 💰
- `capacity-oversubscribed` - High demand ⚠️

## 🛠️ Troubleshooting

### "Unable to fetch spot pricing data"
- Check AWS credentials: `aws sts get-caller-identity`
- Verify region access: `aws ec2 describe-regions`

### "No recent spot requests found"
- Normal if you haven't used spot instances recently
- Indicates no obvious capacity issues

### Dry-run results
- ✅ `Spot request validation passed` - Everything looks good!
- ✅ `(test key rejected as expected)` - Normal, indicates good validation
- ⚠️ `Unsupported` - Instance type may not support spot instances  
- ❌ Permission errors - Check IAM permissions

**Note:** The "InvalidKeyPair.NotFound" message is **expected and good** - it means AWS validated your permissions and capacity, but rejected our fake test key (exactly as intended).

## 💡 Pro Tips

1. **Best times for spot instances:**
   - Weekends and evenings (lower demand)
   - Check multiple times per day as prices fluctuate

2. **Alternative instance types to try:**
   ```bash
   # If c7i.4xlarge too expensive/unavailable
   export TF_VAR_instance_type="c6i.4xlarge"   # Previous generation
   export TF_VAR_instance_type="c7i.2xlarge"   # Smaller size
   export TF_VAR_instance_type="m7i.4xlarge"   # Different family
   ```

3. **Monitor spot prices over time:**
   ```bash
   # Check prices every 30 minutes
   watch -n 1800 './spot-check prices'
   ```

4. **Automated workflow:**
   ```bash
   # Only launch spot if prices are good
   if ./spot-check | grep -q "✅ Spot instances look viable"; then
     export TF_VAR_use_spot_instances="true"
   else
     export TF_VAR_use_spot_instances="false"
   fi
   terraform apply
   ```

## 🔄 Integration with Terraform

The spot checker integrates with the dynamic AZ selection we implemented:

1. **Checker identifies best AZs** → `us-west-2c, us-west-2b, us-west-2d`
2. **Terraform uses dynamic AZ selection** → Tries AZs in order of preference
3. **If spot fails** → Switch to on-demand and retry

This combination provides maximum reliability for instance launches.
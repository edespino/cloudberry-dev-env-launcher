# Automatic Spot Instance Check Feature

## 🎯 Overview

When you enter an environment directory with spot instances enabled, the system now automatically runs a quick spot availability check to help validate your configuration before you run `terraform apply`.

## 🔧 How It Works

### **Automatic Trigger Conditions:**
The auto-check runs when ALL of these are true:
- `TF_VAR_use_spot_instances="true"` (in .envrc)
- Terraform console confirms spot instances enabled
- `CLOUDBERRY_AUTO_SPOT_CHECK="true"` (configurable)

### **What It Shows:**
```bash
🔍 Spot instances enabled - Running automatic availability check...

💰 Current spot prices for c5.4xlarge:
+-------------+------------+
|  us-west-2a |  0.187500  |
|  us-west-2c |  0.182000  |
|  us-west-2b |  0.221900  |
+-------------+------------+
📊 Your max price: $0.50/hour

💡 Run 'spot-check' for detailed capacity analysis before terraform apply
💡 To disable auto-check: export CLOUDBERRY_AUTO_SPOT_CHECK="false"
```

## ⚙️ Configuration Options

### **Enable/Disable Auto-Check:**
```bash
# In your .envrc file:
export CLOUDBERRY_AUTO_SPOT_CHECK="true"   # Enable (default)
export CLOUDBERRY_AUTO_SPOT_CHECK="false"  # Disable
```

### **Timeout Protection:**
- Auto-check has a **30-second timeout** to prevent hanging direnv
- If timeout occurs, shows warning and suggests manual check
- Won't slow down environment loading

## 🎯 Benefits

### **Proactive Issue Detection:**
- **Pricing validation** - See if spot prices fit your budget
- **Quick feedback** - Know immediately if spot looks viable
- **Time saving** - Avoid hanging terraform applies

### **User-Friendly:**
- **Non-intrusive** - Quick price overview only
- **Configurable** - Can be disabled if not wanted
- **Fast** - Times out after 30 seconds max
- **Informative** - Guides you to run full check if needed

## 📋 Sample Environment Template

Add this to your `.envrc` file:

```bash
# Spot instance configuration
export TF_VAR_use_spot_instances="true"
export TF_VAR_spot_max_price="0.50"

# Cloudberry environment options
export CLOUDBERRY_AUTO_SPOT_CHECK="true"  # Set to "false" to disable

# ... rest of your configuration

# Automatic spot availability check when spot instances are enabled
if [[ "$spot_value" == "true" && "$TF_VAR_use_spot_instances" == "true" && "$CLOUDBERRY_AUTO_SPOT_CHECK" == "true" ]]; then
    echo "🔍 Spot instances enabled - Running automatic availability check..."
    echo ""
    
    # Run spot check with timeout to avoid hanging direnv
    REPO_ROOT="$(cd ../.. && pwd)"
    if timeout 30s "$REPO_ROOT/bin/spot-check" prices 2>/dev/null; then
        echo ""
        echo "💡 Run 'spot-check' for detailed capacity analysis before terraform apply"
        echo "💡 To disable auto-check: export CLOUDBERRY_AUTO_SPOT_CHECK=\"false\""
    else
        echo "⚠️  Spot check timed out or failed - consider running 'spot-check' manually"
        echo "💡 To disable auto-check: export CLOUDBERRY_AUTO_SPOT_CHECK=\"false\""
    fi
    echo ""
fi
```

## 🔄 Workflow Integration

### **Typical User Experience:**

1. **Enter environment** → Auto-check runs automatically
2. **See pricing** → Quick validation of spot viability  
3. **Run terraform** → Apply with confidence or investigate further

### **When Issues Detected:**
```bash
# If prices look high or capacity issues suspected
spot-check  # Run full analysis

# If spot not viable, switch to on-demand
export TF_VAR_use_spot_instances="false"
terraform apply
```

## 💡 Pro Tips

- **Keep it enabled** for environments you use frequently
- **Disable temporarily** if you're doing rapid testing: `export CLOUDBERRY_AUTO_SPOT_CHECK="false"`
- **Use with dynamic AZ selection** for maximum reliability
- **Monitor the output** - it will guide you to run full analysis when needed

This feature makes spot instance usage much more reliable by catching issues before they cause hanging terraform operations!
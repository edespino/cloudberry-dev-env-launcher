#!/bin/bash
# Shared Spot Instance Availability Checker Functions
# Used by: bin/spot-check and environment .env files

# =============================================================================
# SPOT INSTANCE AVAILABILITY CHECKER
# =============================================================================

# Comprehensive spot instance availability checker
check_spot_availability() {
  local instance_type="${TF_VAR_instance_type}"
  local region="${TF_VAR_region}"
  local max_price="${TF_VAR_spot_max_price:-0.50}"
  local ami="${TF_VAR_ami}"
  
  echo "🔍 Checking spot availability for ${instance_type} in ${region}..."
  echo "📊 Max price budget: \$${max_price}/hour"
  echo ""
  
  # Get spot price data first (needed for on-demand estimation)
  local prices_output=$(aws ec2 describe-spot-price-history \
    --instance-types "$instance_type" \
    --product-descriptions "Linux/UNIX" \
    --max-items 20 \
    --region "$region" \
    --query 'SpotPriceHistory | sort_by(@, &Timestamp) | reverse(@)[*].[AvailabilityZone,SpotPrice,Timestamp]' \
    --output text 2>/dev/null)
  
  if [ -z "$prices_output" ]; then
    echo "❌ Unable to fetch spot pricing data"
    return 1
  fi

  # Get on-demand pricing for comparison (attempt multiple methods)
  echo "💰 Current pricing comparison (Spot vs On-Demand):"
  local ondemand_price=""
  local pricing_source=""
  
  # Method 1: Try AWS Pricing API (requires us-east-1 region)
  if command -v jq >/dev/null 2>&1; then
    # Convert region to pricing API location name
    local location_name=""
    case "$region" in
      "us-west-2") location_name="US West (Oregon)" ;;
      "us-west-1") location_name="US West (N. California)" ;;
      "us-east-1") location_name="US East (N. Virginia)" ;;
      "us-east-2") location_name="US East (Ohio)" ;;
      "eu-west-1") location_name="Europe (Ireland)" ;;
      "eu-central-1") location_name="Europe (Frankfurt)" ;;
      "ap-southeast-1") location_name="Asia Pacific (Singapore)" ;;
      *) location_name="US West (Oregon)" ;;  # fallback
    esac
    
    ondemand_price=$(aws pricing get-products \
      --service-code AmazonEC2 \
      --region us-east-1 \
      --filters "Type=TERM_MATCH,Field=instanceType,Value=$instance_type" \
               "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
               "Type=TERM_MATCH,Field=operating-system,Value=Linux" \
               "Type=TERM_MATCH,Field=location,Value=$location_name" \
               "Type=TERM_MATCH,Field=capacitystatus,Value=Used" \
      --query 'PriceList[0]' --output text 2>/dev/null | \
      jq -r '.terms.OnDemand[].priceDimensions[].pricePerUnit.USD' 2>/dev/null | head -1)
    
    if [[ -n "$ondemand_price" && "$ondemand_price" != "null" ]]; then
      pricing_source="AWS Pricing API"
    fi
  fi
  
  # Method 2: Estimate based on typical spot discounts (60-80% off on-demand)
  if [[ -z "$ondemand_price" || "$ondemand_price" == "null" ]]; then
    # Get average spot price to estimate on-demand (tab-separated format: AZ price timestamp)  
    local avg_spot=$(echo "$prices_output" | awk -F'\t' '{sum+=$2; count++} END {if(count>0) printf "%.4f", sum/count}' 2>/dev/null)
    if [[ -n "$avg_spot" && "$avg_spot" != "0.0000" ]]; then
      # Estimate on-demand as ~2.5x average spot price (typical 60% discount)
      ondemand_price=$(awk -v spot="$avg_spot" 'BEGIN {printf "%.4f", spot * 2.5}' 2>/dev/null)
      pricing_source="estimated from spot (~60% discount)"
    else
      ondemand_price="N/A"
      pricing_source="unable to estimate"
    fi
  fi
  
  # Display pricing info
  if [[ "$ondemand_price" != "N/A" ]]; then
    echo "  📊 On-Demand price: \$$ondemand_price/hour ($pricing_source)"
  else
    echo "  📊 On-Demand price: $ondemand_price ($pricing_source)"
    echo "  💡 Visit https://aws.amazon.com/ec2/pricing/on-demand/ for current rates"
  fi
  echo ""
  
  local affordable_azs=()
  local expensive_azs=()
  local has_affordable=false
  local seen_azs=""
  
  # Process each line, keeping only the first (latest) entry for each AZ
  while IFS=$'\t' read -r az price timestamp; do
    # Skip empty lines or invalid data
    if [[ -z "$az" || -z "$price" || "$az" == "None" || "$price" == "" ]]; then
      continue
    fi
    
    # Skip if we've already seen this AZ (since data is sorted by timestamp desc)
    if [[ "$seen_azs" == *"|$az|"* ]]; then
      continue
    fi
    seen_azs="$seen_azs|$az|"
    
    # Use awk for floating point comparison and calculate savings
    if command -v awk >/dev/null 2>&1; then
      local comparison=$(awk -v p="$price" -v m="$max_price" 'BEGIN { print (p <= m) ? "within" : "exceeds" }' 2>/dev/null)
      local savings_info=""
      
      # Calculate savings vs on-demand if we have valid prices
      if [[ "$ondemand_price" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        local savings=$(awk -v spot="$price" -v demand="$ondemand_price" 'BEGIN { 
          if (demand > 0) {
            percent = ((demand - spot) / demand) * 100
            printf "%.0f%% off", percent
          } else {
            print "N/A"
          }
        }' 2>/dev/null)
        savings_info=" ($savings on-demand)"
      elif [[ "$ondemand_price" == "N/A" ]]; then
        savings_info=" (vs on-demand N/A)"
      fi
      
      if [[ "$comparison" == "within" ]]; then
        echo "  ✅ $az: \$$price (within budget)$savings_info"
        affordable_azs+=("$az")
        has_affordable=true
      else
        echo "  ❌ $az: \$$price (exceeds \$$max_price)$savings_info"
        expensive_azs+=("$az")
      fi
    else
      # Simple string comparison fallback
      echo "  ℹ️  $az: \$$price (manual check needed)"
    fi
  done <<< "$prices_output"
  
  echo ""
  
  # Check recent spot instance request failures (expanded timeframe and better analysis)
  echo "📋 Recent spot instance request history (last 6 hours):"
  local recent_requests=$(aws ec2 describe-spot-instance-requests \
    --region "$region" \
    --filters "Name=launch.instance-type,Values=$instance_type" \
    --query 'SpotInstanceRequests[*].[State,Status.Code,Status.Message,LaunchSpecification.Placement.AvailabilityZone,CreateTime]' \
    --output text 2>/dev/null | head -10)
  
  local capacity_failures=0
  
  if [ -n "$recent_requests" ]; then
    # First, display the requests
    echo "$recent_requests" | head -8 | while IFS=$'\t' read -r state code message az create_time; do
      # Extract just the time portion for display
      local time_display=""
      if [[ -n "$create_time" ]]; then
        time_display=" - $(date -d "$create_time" '+%H:%M' 2>/dev/null || echo "recent")"
      fi
      
      case "$state" in
        "active") echo "  ✅ $az: Active (Success)$time_display" ;;
        "open") echo "  ⏳ $az: Open (Pending)$time_display" ;;
        "closed") 
          case "$code" in
            "fulfilled") echo "  ✅ $az: Fulfilled (Success)$time_display" ;;
            "capacity-not-available") echo "  ❌ $az: No capacity available$time_display" ;;
            "instance-terminated-no-capacity") echo "  ❌ $az: Instance terminated - no capacity$time_display" ;;
            "price-too-low") echo "  💰 $az: Price too low$time_display" ;;
            "capacity-oversubscribed") echo "  ⚠️  $az: Capacity oversubscribed$time_display" ;;
            *) echo "  ❓ $az: $code$time_display" ;;
          esac
          ;;
        "cancelled") echo "  🚫 $az: Cancelled$time_display" ;;
        "failed") echo "  ❌ $az: Failed$time_display" ;;
        *) echo "  ❓ $az: $state ($code)$time_display" ;;
      esac
    done
    
    # Count capacity failures in the data
    capacity_failures=$(echo "$recent_requests" | grep -c -E "(capacity-not-available|instance-terminated-no-capacity|capacity-oversubscribed)" 2>/dev/null)
    if [[ -z "$capacity_failures" ]]; then
      capacity_failures=0
    fi
    if [ "$capacity_failures" -gt 0 ]; then
      echo ""
      echo "  ⚠️  WARNING: $capacity_failures recent capacity-related failures detected!"
      has_affordable=false  # Override the pricing assessment
    fi
  else
    echo "  ℹ️  No recent spot requests found for $instance_type"
  fi
  
  echo ""
  
  # Test spot capacity with dry run
  echo "🧪 Testing spot request capacity (dry-run)..."
  local dry_run_result=$(aws ec2 request-spot-instances \
    --spot-price "$max_price" \
    --instance-count 1 \
    --type "one-time" \
    --launch-specification "{
      \"ImageId\":\"$ami\",
      \"InstanceType\":\"$instance_type\",
      \"KeyName\":\"test-key\",
      \"SecurityGroups\":[\"default\"]
    }" \
    --region "$region" \
    --dry-run 2>&1)
  
  if echo "$dry_run_result" | grep -q "DryRunOperation"; then
    echo "  ✅ Spot request validation passed"
  elif echo "$dry_run_result" | grep -q "InvalidKeyPair.NotFound"; then
    echo "  ✅ Spot request validation passed (test key rejected as expected)"
  elif echo "$dry_run_result" | grep -q "Unsupported"; then
    echo "  ⚠️  Instance type may not support spot instances"
  elif echo "$dry_run_result" | grep -q "InvalidAMIID"; then
    echo "  ⚠️  AMI validation issue (expected for dry-run)"
  else
    echo "  ❌ Potential issues detected:"
    echo "$dry_run_result" | grep -E "(Error|Invalid)" | head -3 | sed 's/^/    /'
  fi
  
  echo ""
  
  # Provide recommendations
  echo "🎯 Recommendations:"
  # Recompute capacity failures for recommendations scope
  local rec_capacity_failures=0
  if [ -n "$recent_requests" ]; then
    rec_capacity_failures=$(echo "$recent_requests" | grep -c -E "(capacity-not-available|instance-terminated-no-capacity|capacity-oversubscribed)" 2>/dev/null)
    if [[ -z "$rec_capacity_failures" ]]; then
      rec_capacity_failures=0
    fi
  fi
  
  if [[ "$has_affordable" == "true" && "$rec_capacity_failures" -eq 0 ]]; then
    echo "  ✅ Spot instances look viable"
    # Remove duplicates and show unique AZs
    local unique_azs=($(printf "%s\n" "${affordable_azs[@]}" | sort -u | tr '\n' ' '))
    echo "  🎯 Best AZs to try: ${unique_azs[*]}"
  elif [[ "$rec_capacity_failures" -gt 0 ]]; then
    echo "  ⚠️  CAPACITY ISSUES DETECTED - spot instances likely to hang/fail"
    echo "  🚨 Recent failures: $rec_capacity_failures capacity-related issues"
    echo "  💡 Recommended actions:"
    echo "    1. Switch to on-demand instances (export TF_VAR_use_spot_instances=\"false\")"
    echo "    2. Try smaller instance type (c7i.2xlarge, c6i.4xlarge, c5.4xlarge)" 
    echo "    3. Try different instance family (m7i.4xlarge, r7i.4xlarge)"
    echo "    4. Wait 1-2 hours and retry"
  else
    echo "  ⚠️  Consider switching to on-demand instances (pricing concerns)"
    echo "  💡 Or try a smaller instance type (e.g., c7i.2xlarge, c6i.4xlarge)"
  fi
  
  # Show current configuration
  echo ""
  echo "🔧 Current configuration:"
  echo "  Instance Type: $instance_type"
  echo "  Max Spot Price: \$$max_price/hour"
  echo "  Spot Enabled: ${TF_VAR_use_spot_instances}"
  echo "  Region: $region"
}

# Quick spot price check (abbreviated version)
check_spot_prices() {
  local instance_type="${TF_VAR_instance_type}"
  local region="${TF_VAR_region}"
  local max_price="${TF_VAR_spot_max_price:-0.50}"
  
  echo "💰 Current spot prices for ${instance_type}:"
  aws ec2 describe-spot-price-history \
    --instance-types "$instance_type" \
    --product-descriptions "Linux/UNIX" \
    --max-items 4 \
    --region "$region" \
    --query 'SpotPriceHistory[*].[AvailabilityZone,SpotPrice]' \
    --output table
  echo "📊 Your max price: \$$max_price/hour"
}
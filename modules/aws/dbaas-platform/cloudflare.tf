# ============================================================================
# CLOUDFLARE DNS CONFIGURATION
# ============================================================================
# Manages DNS records for external access to DBaaS UI via ALB.
# ============================================================================

# Cloudflare DNS record created via CLI (to avoid count dependency on computed values)
resource "null_resource" "cloudflare_dns_record" {
  count = var.enable_alb_ingress && var.enable_cloudflare_dns ? 1 : 0

  triggers = {
    domain_name      = local.domain_name
    zone_id          = var.cloudflare_zone_id
    api_token        = var.cloudflare_api_token
    ingress_id       = null_resource.alb_ingress[0].id
    proxy_enabled    = var.cloudflare_proxy_enabled
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Get ALB hostname from Ingress
      ALB_HOSTNAME=$(kubectl get ingress dbaas-ui-ingress -n ${var.dbaas_namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

      if [ -z "$ALB_HOSTNAME" ]; then
        echo "⚠️  Warning: ALB hostname not available yet. DNS record not created."
        exit 0
      fi

      echo "📝 Creating Cloudflare DNS record for ${local.domain_name} -> $ALB_HOSTNAME"

      # Check if record already exists
      EXISTING_RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${var.cloudflare_zone_id}/dns_records?name=${local.domain_name}" \
        -H "Authorization: Bearer ${var.cloudflare_api_token}" \
        -H "Content-Type: application/json" | jq -r '.result[0].id // empty')

      if [ -n "$EXISTING_RECORD_ID" ] && [ "$EXISTING_RECORD_ID" != "null" ]; then
        # Update existing record
        echo "📝 Updating existing Cloudflare DNS record: $EXISTING_RECORD_ID"
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${var.cloudflare_zone_id}/dns_records/$EXISTING_RECORD_ID" \
          -H "Authorization: Bearer ${var.cloudflare_api_token}" \
          -H "Content-Type: application/json" \
          --data "{\"type\":\"CNAME\",\"name\":\"${local.domain_name}\",\"content\":\"$ALB_HOSTNAME\",\"ttl\":${var.cloudflare_dns_ttl},\"proxied\":${var.cloudflare_proxy_enabled},\"comment\":\"DBaaS UI - ALB CNAME - Managed by Terraform\"}" \
          | jq -r '.success'
      else
        # Create new record
        echo "📝 Creating new Cloudflare DNS record"
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${var.cloudflare_zone_id}/dns_records" \
          -H "Authorization: Bearer ${var.cloudflare_api_token}" \
          -H "Content-Type: application/json" \
          --data "{\"type\":\"CNAME\",\"name\":\"${local.domain_name}\",\"content\":\"$ALB_HOSTNAME\",\"ttl\":${var.cloudflare_dns_ttl},\"proxied\":${var.cloudflare_proxy_enabled},\"comment\":\"DBaaS UI - ALB CNAME - Managed by Terraform\"}" \
          | jq -r '.success'
      fi

      echo "✅ Cloudflare DNS record created/updated successfully"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Delete Cloudflare DNS record on destroy
      RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${self.triggers.zone_id}/dns_records?name=${self.triggers.domain_name}" \
        -H "Authorization: Bearer ${self.triggers.api_token}" \
        -H "Content-Type: application/json" | jq -r '.result[0].id // empty')

      if [ -n "$RECORD_ID" ] && [ "$RECORD_ID" != "null" ]; then
        echo "🗑️  Deleting Cloudflare DNS record: $RECORD_ID"
        curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${self.triggers.zone_id}/dns_records/$RECORD_ID" \
          -H "Authorization: Bearer ${self.triggers.api_token}" \
          -H "Content-Type: application/json"
        echo "✅ Cloudflare DNS record deleted"
      fi
    EOT
  }

  depends_on = [
    null_resource.wait_for_alb
  ]
}

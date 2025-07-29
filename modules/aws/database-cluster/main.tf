# Local values for computed configurations
locals {
  # Default hostnames if not provided
  default_hostnames = [
    for i in range(var.vm_count) : i == 0 ? "cdw" : "sdw${i}"
  ]
  hostnames = length(var.hostnames) > 0 ? var.hostnames : local.default_hostnames

  # Spot instance configuration
  spot_instance_map = {
    for i in range(var.vm_count) : i => (
      !var.use_spot_instances ? false :
      var.spot_instance_strategy == "none" ? false :
      var.spot_instance_strategy == "all" ? true :
      var.spot_instance_strategy == "workers" ? (i > 0) :
      var.spot_instance_strategy == "mixed" ? (i % 2 == 1) :
      false
    )
  }

  # Combined tags
  common_tags = merge(var.additional_tags, {
    Environment = var.env_prefix
    ManagedBy   = "Terraform"
    Module      = "database-cluster"
  })

  # Cloud-init configuration
  cloud_init_content = var.cloud_init_template != null ? file(var.cloud_init_template) : templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    hostname         = "HOSTNAME_PLACEHOLDER"
    vm_count         = var.vm_count
    env_prefix       = var.env_prefix
    default_username = var.default_username
  })
}
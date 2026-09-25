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
    Environment = var.environment_tag != "" ? var.environment_tag : var.env_prefix
    ManagedBy   = "Terraform"
    Module      = "database-cluster"
  }, var.owner_tag != "" ? { Owner = var.owner_tag } : {})

  # Session Manager mode: no laptop-facing ingress; intra-VPC rules only
  ssm_only       = var.access_mode == "ssm"
  laptop_cidrs   = local.ssm_only ? [] : ["${var.my_ip}/32"]
  app_port_cidrs = concat(local.laptop_cidrs, ["10.0.0.0/16"])

  # Cloud-init configuration
  cloud_init_content = var.cloud_init_template != null ? file(var.cloud_init_template) : templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    hostname         = "HOSTNAME_PLACEHOLDER"
    vm_count         = var.vm_count
    env_prefix       = var.env_prefix
    default_username = var.default_username
  })
}
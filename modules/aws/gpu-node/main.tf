# GPU node: one stoppable, on-demand NVIDIA L4 instance attached to an existing
# environment's subnet, security group, and key pair. Nothing here creates or
# modifies network resources.

data "aws_region" "current" {}

locals {
  name = "${var.name_prefix}-${var.node_name}"

  # Empty string behaves like null (lets .envrc export an empty value safely).
  private_ip = var.private_ip == "" ? null : var.private_ip

  # Network address of private_ip under the subnet's prefix length; equals the
  # subnet's own network address exactly when the IP is inside the subnet.
  private_ip_in_subnet = (
    local.private_ip == null || var.subnet_cidr_block == null
    ? true
    : cidrhost("${local.private_ip}/${split("/", var.subnet_cidr_block)[1]}", 0) == cidrhost(var.subnet_cidr_block, 0)
  )

  common_tags = merge(var.additional_tags, {
    Environment = var.name_prefix
    ManagedBy   = "Terraform"
    Module      = "gpu-node"
    Role        = "selfhost-gpu"
  })
}

resource "aws_instance" "this" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  private_ip                  = local.private_ip
  vpc_security_group_ids      = concat([var.security_group_id], aws_security_group.ollama[*].id)
  key_name                    = var.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.this.name

  # On-demand only. No instance_market_options, no placement group.

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    iops        = var.root_volume_iops
    throughput  = var.root_volume_throughput
    encrypted   = var.root_volume_encrypted

    tags = merge(local.common_tags, {
      Name = "${local.name}-root"
    })
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Hostname, plus (only when ollama_bind = "all") a systemd drop-in that makes
  # an already-installed Ollama listen on 0.0.0.0. No driver, CUDA, Ollama, or
  # Docker install here.
  user_data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    hostname        = var.hostname
    ollama_bind     = var.ollama_bind
    authorized_keys = var.authorized_ssh_public_keys
  })

  tags = merge(local.common_tags, {
    Name         = local.name
    Hostname     = var.hostname
    InstanceType = "on-demand"
  })

  lifecycle {
    # A newer AMI must never replace this instance: the root volume holds model weights.
    # To rebuild deliberately: terraform apply -replace=module.<name>.aws_instance.this
    ignore_changes = [ami]

    precondition {
      condition     = var.expected_subnet_id == null || var.subnet_id == var.expected_subnet_id
      error_message = "Resolved subnet_id does not match expected_subnet_id. Refusing to build in an unexpected subnet."
    }

    precondition {
      condition     = local.private_ip_in_subnet
      error_message = "private_ip is outside subnet_cidr_block. Pick an address inside the parent subnet (not one of the first four or the last address, which AWS reserves)."
    }
  }
}

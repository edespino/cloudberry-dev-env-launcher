terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------------------
# Parent environment (created by modules/aws/database-cluster).
# Read-only lookups by the tags that module sets. Nothing in the parent is
# modified by this root, and its state file is never opened by Terraform.
# ---------------------------------------------------------------------------

data "aws_vpc" "parent" {
  filter {
    name   = "tag:Name"
    values = ["${var.parent_prefix}-vpc"]
  }
}

data "aws_subnet" "parent" {
  vpc_id = data.aws_vpc.parent.id

  filter {
    name   = "tag:Name"
    values = ["${var.parent_prefix}-public-subnet"]
  }
}

data "aws_security_group" "parent" {
  vpc_id = data.aws_vpc.parent.id

  filter {
    name   = "tag:Name"
    values = ["${var.parent_prefix}-sg"]
  }
}

data "aws_key_pair" "parent" {
  key_name = "${var.parent_prefix}-generated_key"
}

# ---------------------------------------------------------------------------
# GPU node
# ---------------------------------------------------------------------------

module "gpu_node" {
  source = "../../modules/aws/gpu-node"

  name_prefix = var.parent_prefix
  node_name   = var.node_name
  hostname    = var.hostname

  ami           = var.gpu_ami
  instance_type = var.instance_type

  subnet_id          = data.aws_subnet.parent.id
  security_group_id  = data.aws_security_group.parent.id
  key_name           = data.aws_key_pair.parent.key_name
  expected_subnet_id = var.parent_subnet_id # from the parent's state via .envrc; plan fails on mismatch

  root_volume_size = var.root_volume_size

  # Optional pinned private IP (survives rebuilds); checked against the subnet CIDR at plan time.
  private_ip        = var.private_ip
  subnet_cidr_block = data.aws_subnet.parent.cidr_block

  # Public keys collected by `lpair` (paired_keys.pub) are trusted from first boot.
  authorized_ssh_public_keys = var.authorized_ssh_public_keys

  # Ollama exposure. Default is loopback + SSH tunnel; .envrc sets these from OLLAMA_ACCESS.
  vpc_id              = data.aws_vpc.parent.id
  ollama_bind         = var.ollama_bind
  ollama_client_cidrs = var.ollama_client_cidrs

  additional_tags = {
    Project = "Cloudberry Database Environment"
    Purpose = "Self-hosted GPU inference"
  }
}

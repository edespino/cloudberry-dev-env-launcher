# Parent environment (set by .envrc from PARENT_ENV_DIR)
variable "parent_prefix" {
  description = "env_prefix of the parent environment. Derived by .envrc from the parent's ssh_key output."
  type        = string
}

variable "parent_subnet_id" {
  description = "Subnet ID recorded in the parent's state. Used only as a plan-time guard against the tag lookup."
  type        = string
  default     = null
}

variable "region" {
  description = "AWS region. Must match the parent environment."
  type        = string
  default     = "us-west-2"
}

# GPU node
variable "node_name" {
  description = "Node name appended to parent_prefix for every resource name."
  type        = string
  default     = "gpu-l4"
}

variable "hostname" {
  description = "Linux hostname of the GPU node."
  type        = string
  default     = "gpu"
}

variable "gpu_ami" {
  description = "x86_64 AMI ID. Resolved by .envrc from AMI_OWNER / AMI_FILTER."
  type        = string
}

variable "instance_type" {
  description = "g6.2xlarge (default) or g6.xlarge."
  type        = string
  default     = "g6.2xlarge"
}

variable "root_volume_size" {
  description = "Root volume size in GiB (gp3). Model weights live here."
  type        = number
  default     = 200
}

# Ollama exposure (set by .envrc from OLLAMA_ACCESS)
variable "ollama_bind" {
  description = "loopback (tunnel only) or all (VPC clients, plus ollama_client_cidrs)."
  type        = string
  default     = "loopback"
}

variable "ollama_client_cidrs" {
  description = "IPv4 CIDRs allowed to reach 11434 from outside the VPC (for example the laptop /32)."
  type        = list(string)
  default     = []
}

variable "private_ip" {
  description = "Fixed private IPv4 for the node inside the parent subnet (empty = DHCP). Set by .envrc from GPU_PRIVATE_IP."
  type        = string
  default     = null
}

variable "authorized_ssh_public_keys" {
  description = "Public keys baked into the node's default user at boot (from paired_keys.pub via .envrc)."
  type        = list(string)
  default     = []
}

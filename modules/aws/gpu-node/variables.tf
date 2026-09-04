# Naming
variable "name_prefix" {
  description = "Prefix of the parent environment (its env_prefix). Every name this module creates is <name_prefix>-<node_name>."
  type        = string
}

variable "node_name" {
  description = "Short node name appended to name_prefix. Must be unique per parent environment (IAM role names are account-unique)."
  type        = string
  default     = "gpu-l4"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,31}$", var.node_name))
    error_message = "node_name must be 1-32 characters of lowercase letters, digits, or hyphens, starting with a letter or digit."
  }
}

variable "hostname" {
  description = "Linux hostname set by cloud-init."
  type        = string
  default     = "gpu"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,62}$", var.hostname))
    error_message = "hostname must be a valid single-label hostname (lowercase letters, digits, hyphens)."
  }
}

# Placement (resolved by the caller, typically from data sources on the parent environment)
variable "subnet_id" {
  description = "Subnet to launch into. Same subnet as the parent environment's instances."
  type        = string
}

variable "expected_subnet_id" {
  description = "Optional guard. When set, the plan fails unless subnet_id equals this value. Feed it from an independent source (for example the parent's state) so a wrong tag lookup cannot build in the wrong subnet."
  type        = string
  default     = null
}

variable "security_group_id" {
  description = "Existing security group to attach. The module adds no rules. Port 11434 is never opened; Ollama is reached over an SSH tunnel only."
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name (the parent environment's generated key)."
  type        = string
}

# Instance
variable "ami" {
  description = "x86_64 AMI ID. The g6 family is x86_64 only. AMI changes are ignored after creation (see lifecycle) so a newer image never rebuilds the node and wipes model weights."
  type        = string
  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ami))
    error_message = "ami must be an AMI ID of the form ami-xxxxxxxx."
  }
}

variable "instance_type" {
  description = "NVIDIA L4 instance type."
  type        = string
  default     = "g6.2xlarge"
  validation {
    condition     = contains(["g6.2xlarge", "g6.xlarge"], var.instance_type)
    error_message = "instance_type must be g6.2xlarge (default, 32 GiB host RAM) or g6.xlarge (16 GiB host RAM)."
  }
}

# Root volume (gp3). Defaults match the database-cluster module's root disk settings.
variable "root_volume_size" {
  description = "Root volume size in GiB. Model weights live here (the GPU image itself uses about 15 GiB)."
  type        = number
  default     = 200
  validation {
    condition     = var.root_volume_size >= 100
    error_message = "root_volume_size must be at least 100 GiB."
  }
}

variable "root_volume_iops" {
  description = "Root volume IOPS (gp3: 3000-16000)."
  type        = number
  default     = 8000
  validation {
    condition     = var.root_volume_iops >= 3000 && var.root_volume_iops <= 16000
    error_message = "root_volume_iops must be between 3000 and 16000."
  }
}

variable "root_volume_throughput" {
  description = "Root volume throughput in MB/s (gp3: 125-1000)."
  type        = number
  default     = 500
  validation {
    condition     = var.root_volume_throughput >= 125 && var.root_volume_throughput <= 1000
    error_message = "root_volume_throughput must be between 125 and 1000."
  }
}

variable "root_volume_encrypted" {
  description = "Encrypt the root volume. Default false matches the database-cluster module's instances."
  type        = bool
  default     = false
}

# Tags
variable "additional_tags" {
  description = "Additional tags applied to every resource."
  type        = map(string)
  default     = {}
}

# Ollama exposure. Default keeps the original rule: loopback only, SSH tunnel access.
variable "vpc_id" {
  description = "VPC of the subnet. Required only when ollama_client_cidrs is non-empty (the Ollama security group is created in it)."
  type        = string
  default     = null
}

variable "ollama_bind" {
  description = "Where Ollama listens. loopback: 127.0.0.1:11434 (image default, tunnel access only). all: 0.0.0.0:11434 via a systemd drop-in written by cloud-init; reachability is then bounded by the security groups (the parent SG already allows all TCP inside the VPC)."
  type        = string
  default     = "loopback"
  validation {
    condition     = contains(["loopback", "all"], var.ollama_bind)
    error_message = "ollama_bind must be loopback or all."
  }
}

variable "ollama_client_cidrs" {
  description = "IPv4 CIDRs allowed to reach 11434/tcp from outside the VPC (for example the laptop /32). Non-empty creates a dedicated security group attached next to the parent's. 0.0.0.0/0 and IPv6 are rejected: Ollama has no authentication."
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for c in var.ollama_client_cidrs : can(cidrnetmask(c)) && c != "0.0.0.0/0"
    ])
    error_message = "ollama_client_cidrs must be IPv4 CIDRs and must not include 0.0.0.0/0."
  }
}

# Optional fixed private IPv4. Without it the address is DHCP-assigned and
# changes on every rebuild (it already survives stop/start either way).
variable "private_ip" {
  description = "Fixed primary private IPv4 inside the subnet, so rebuilds keep the same address (for cdw's /etc/hosts, SSH config, Ollama URL). null or empty = DHCP."
  type        = string
  default     = null
  validation {
    condition     = var.private_ip == null || var.private_ip == "" || can(cidrhost("${var.private_ip}/32", 0))
    error_message = "private_ip must be an IPv4 address or empty."
  }
}

variable "subnet_cidr_block" {
  description = "CIDR of subnet_id. When given together with private_ip, the plan fails if the address is outside the subnet instead of failing at apply."
  type        = string
  default     = null
}

variable "authorized_ssh_public_keys" {
  description = "Extra SSH public keys added to the default user's authorized_keys by cloud-init at boot (for example cdw's key), so a rebuilt node trusts them without re-pairing. Public keys only."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for k in var.authorized_ssh_public_keys : can(regex("^(ssh-(ed25519|rsa)|ecdsa-sha2-nistp[0-9]+|sk-ssh-ed25519@openssh.com) [A-Za-z0-9+/=]+", k))])
    error_message = "authorized_ssh_public_keys entries must be OpenSSH public keys (ssh-ed25519 ..., ssh-rsa ..., ecdsa-sha2-... )."
  }
}

# Optional security group for direct Ollama API access from approved client
# CIDRs (typically the laptop /32). Attached next to the parent's SG; the
# parent SG is never modified. Inside the VPC the parent SG already allows all
# TCP, so this SG is only about clients outside the VPC.

resource "aws_security_group" "ollama" {
  count = length(var.ollama_client_cidrs) > 0 ? 1 : 0

  name_prefix = "${local.name}-ollama-"
  description = "Ollama API 11434/tcp from approved client CIDRs"
  vpc_id      = var.vpc_id

  ingress {
    description = "Ollama API"
    from_port   = 11434
    to_port     = 11434
    protocol    = "tcp"
    cidr_blocks = var.ollama_client_cidrs
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-ollama-sg"
  })

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.ollama_bind == "all"
      error_message = "ollama_client_cidrs is set but ollama_bind is loopback; clients could never connect. Set ollama_bind = \"all\"."
    }

    precondition {
      condition     = var.vpc_id != null
      error_message = "vpc_id is required when ollama_client_cidrs is non-empty."
    }
  }
}

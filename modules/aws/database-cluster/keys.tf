# SSH Key Management

# Generate SSH key pair
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# AWS Key Pair
resource "aws_key_pair" "generated_key" {
  key_name   = "${var.env_prefix}-generated_key"
  public_key = tls_private_key.example.public_key_openssh

  tags = local.common_tags
}

# Create PEM file locally
resource "null_resource" "pem_file" {
  provisioner "local-exec" {
    command = <<EOT
      echo '${tls_private_key.example.private_key_pem}' > ${var.env_prefix}_generated_key.pem
      chmod 400 ${var.env_prefix}_generated_key.pem
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${self.triggers.filename}"
  }

  triggers = {
    private_key = tls_private_key.example.private_key_pem
    filename    = "${var.env_prefix}_generated_key.pem"
  }
}
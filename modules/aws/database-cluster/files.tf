# Local File Generation and Inventory Management

# Store instance information
resource "local_file" "instances_info" {
  content = jsonencode({
    ips   = aws_instance.database_instances[*].public_ip
    names = aws_instance.database_instances[*].tags.Name
  })
  filename = "${var.env_prefix}_instances_info.json"
}

# Optional: Ansible inventory generation (legacy feature)
resource "null_resource" "generate_inventory" {
  count = var.generate_inventory ? 1 : 0

  provisioner "local-exec" {
    environment = {
      INVENTORY_FILE    = "${path.cwd}/${var.env_prefix}_inventory.ini"
      INFO_FILE         = "${path.cwd}/${var.env_prefix}_instances_info.json"
      GENERATED_KEY_PEM = "${path.cwd}/${var.env_prefix}_generated_key.pem"
    }
    command     = <<EOT
      #!/bin/bash
      set -e

      echo "[vms]" > $INVENTORY_FILE

      count=$(jq '.names | length' $INFO_FILE)
      for i in $(seq 0 $(($count - 1))); do
        name=$(jq -r ".names[$i]" $INFO_FILE)
        ip=$(jq -r ".ips[$i]" $INFO_FILE)
        echo "$name ansible_host=$ip ansible_user=${var.default_username} ansible_ssh_private_key_file=$GENERATED_KEY_PEM" >> $INVENTORY_FILE
      done
      
      echo "✅ Ansible inventory generated: ${var.env_prefix}_inventory.ini"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  triggers = {
    instance_ips = join(",", aws_instance.database_instances[*].public_ip)
  }
  depends_on = [local_file.instances_info]
}

# Cleanup inventory file on destroy
resource "null_resource" "remove_inventory" {
  count = var.generate_inventory ? 1 : 0

  provisioner "local-exec" {
    command     = "rm -f ${self.triggers.inventory_file_path}"
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
  }

  triggers = {
    inventory_file_path = "${path.cwd}/${var.env_prefix}_inventory.ini"
  }
}
# EC2 Compute Resources

# EC2 Instances
resource "aws_instance" "database_instances" {
  count                       = var.vm_count
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.allow_all.id]
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_cluster_discovery.name
  placement_group             = aws_placement_group.cluster.id

  # Spot instance configuration
  dynamic "instance_market_options" {
    for_each = local.spot_instance_map[count.index] ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price                      = var.spot_max_price
        spot_instance_type             = "one-time"
        instance_interruption_behavior = "terminate"
      }
    }
  }

  # Root disk configuration
  root_block_device {
    volume_size = var.root_disk_size
    volume_type = "gp3"
    iops        = var.root_disk_iops
    throughput  = var.root_disk_throughput

    tags = merge(local.common_tags, {
      Name        = "${var.env_prefix}-root-volume-${count.index}"
      Performance = "Optimized"
      IOPS        = var.root_disk_iops
      Throughput  = "${var.root_disk_throughput}MB/s"
    })
  }

  # User data with hostname replacement
  user_data = replace(
    local.cloud_init_content,
    "HOSTNAME_PLACEHOLDER",
    local.hostnames[count.index]
  )

  tags = merge(local.common_tags, {
    Name         = "${var.env_prefix}-instance-${count.index}"
    Hostname     = local.hostnames[count.index]
    InstanceType = local.spot_instance_map[count.index] ? "spot" : "on-demand"
    SpotStrategy = var.spot_instance_strategy
  })

  depends_on = [aws_placement_group.cluster]
}
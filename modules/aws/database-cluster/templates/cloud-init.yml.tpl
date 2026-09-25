#cloud-config
hostname: "HOSTNAME_PLACEHOLDER"
fqdn: "HOSTNAME_PLACEHOLDER"
manage_etc_hosts: false

# Create scripts for database cluster setup. Staged under /var/lib, not /tmp:
# some distros mount a fresh tmpfs on /tmp during boot.
write_files:
  - path: /var/lib/launcher-cloud-init/setup-hosts.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      # Build hosts file for database cluster with actual IPs
      
      # Get this instance's private IP and instance ID (IMDSv2: token first;
      # works whether the instance requires IMDSv2 or merely allows it)
      IMDS_TOKEN=$(curl -s --connect-timeout 2 --max-time 5 -X PUT http://169.254.169.254/latest/api/token \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
      imds() {
        curl -s --connect-timeout 2 --max-time 5 -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" "http://169.254.169.254/latest/meta-data/$1"
      }
      PRIVATE_IP=$(imds local-ipv4)
      INSTANCE_ID=$(imds instance-id)
      REGION=$(imds placement/region)
      
      # Create basic hosts file with localhost entries
      cat > /etc/hosts << EOF
      127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
      ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
      
      EOF
      
      # Function to discover all cluster instances and build hosts entries
      discover_cluster_members() {
        local max_attempts=24  # Reduced from 30
        local attempt=1
        local expected_count=${vm_count}
        local sleep_time=5     # Reduced from 10 seconds
        local start_time=$(date +%s)
        local timeout=120      # 2 minute absolute timeout
        
        echo "Discovering cluster members (expecting $expected_count instances, max 2min timeout)..."
        
        while [ $attempt -le $max_attempts ]; do
          local current_time=$(date +%s)
          local elapsed=$((current_time - start_time))
          
          # Check absolute timeout
          if [ $elapsed -ge $timeout ]; then
            echo "Timeout reached after $${elapsed}s, proceeding with partial discovery..."
            break
          fi
          
          echo "Discovery attempt $attempt/$max_attempts ($${elapsed}s elapsed)"
          
          # Get all instances in the same VPC with our naming pattern
          instances=$(aws ec2 describe-instances \
            --region $REGION \
            --filters "Name=tag:Name,Values=${env_prefix}-instance-*" \
                      "Name=instance-state-name,Values=running" \
            --query 'Reservations[].Instances[].{InstanceId:InstanceId,PrivateIp:PrivateIpAddress,Name:Tags[?Key==`Name`].Value|[0]}' \
            --output json 2>/dev/null)
          
          if [ $? -eq 0 ]; then
            instance_count=$(echo "$instances" | jq length 2>/dev/null)
            
            if [ "$instance_count" -eq "$expected_count" ]; then
              echo "Found all $expected_count cluster instances after $${elapsed}s"
              
              # Sort instances by name to ensure consistent ordering
              sorted_instances=$(echo "$instances" | jq 'sort_by(.Name)')
              
              # Add cluster member entries to hosts file
              echo "# Database cluster members" >> /etc/hosts
              echo "$sorted_instances" | jq -r '.[] | .PrivateIp + " " + (.Name | split("-") | last | if . == "0" then "cdw" elif . == "1" then "sdw1" elif . == "2" then "sdw2" elif . == "3" then "sdw3" elif . == "4" then "sdw4" else "sdw" + . end)' >> /etc/hosts
              
              echo "Hosts file updated with all cluster members"
              return 0
            else
              echo "Found $instance_count instances, waiting for $expected_count..."
              # Add partial discovery - if we have some instances, add them
              if [ "$instance_count" -gt 0 ] && [ $elapsed -gt 60 ]; then
                echo "Adding partial cluster discovery after 60s..."
                echo "# Database cluster members (partial)" >> /etc/hosts
                echo "$instances" | jq -r '.[] | .PrivateIp + " " + (.Name | split("-") | last | if . == "0" then "cdw" elif . == "1" then "sdw1" elif . == "2" then "sdw2" elif . == "3" then "sdw3" elif . == "4" then "sdw4" else "sdw" + . end)' >> /etc/hosts
              fi
            fi
          else
            echo "AWS CLI command failed, retrying... (attempt $attempt)"
          fi
          
          # Dynamic sleep - shorter intervals initially, longer as we wait
          if [ $attempt -le 6 ]; then
            sleep_time=3  # First 6 attempts: 3 seconds
          elif [ $attempt -le 12 ]; then
            sleep_time=5  # Next 6 attempts: 5 seconds  
          else
            sleep_time=7  # Final attempts: 7 seconds
          fi
          
          sleep $sleep_time
          attempt=$((attempt + 1))
        done
        
        echo "Warning: Could not discover all cluster members after $max_attempts attempts"
        echo "Adding only this instance to hosts file"
        echo "$PRIVATE_IP HOSTNAME_PLACEHOLDER" >> /etc/hosts
        return 1
      }
      
      # A single node has no peers to discover
      if [ ${vm_count} -eq 1 ]; then
        echo "Single node: adding only this instance to hosts file"
        echo "$PRIVATE_IP HOSTNAME_PLACEHOLDER" >> /etc/hosts
        echo "Final hosts file:"
        cat /etc/hosts
        exit 0
      fi

      # Multi-node discovery needs the AWS CLI. Stock images may lack it; the
      # dnf fallback covers RPM distros whose repos carry it (e.g. Oracle Linux).
      if ! command -v aws &> /dev/null && command -v dnf &> /dev/null; then
        echo "Installing AWS CLI..."
        dnf install -y awscli || true
      fi
      if ! command -v aws &> /dev/null; then
        echo "AWS CLI not available: multi-node discovery skipped; adding only this instance to hosts file"
        echo "$PRIVATE_IP HOSTNAME_PLACEHOLDER" >> /etc/hosts
        echo "Final hosts file:"
        cat /etc/hosts
        exit 0
      fi

      # Try to discover cluster members
      discover_cluster_members
      
      echo "Final hosts file:"
      cat /etc/hosts
  # Staged here and installed by runcmd: write_files runs before cloud-init
  # creates the default user on stock images, and an unknown owner aborts every
  # file after it.
  - path: /var/lib/launcher-cloud-init/cluster-ssh-config
    permissions: "0644"
    content: |
      # SSH config for cluster communication - skip host key checking for internal IPs
      Host 10.0.*
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
          LogLevel QUIET
      
      # SSH config for cluster hostnames
      Host cdw sdw1 sdw2 sdw3 sdw4
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
          LogLevel QUIET
  - path: /var/lib/launcher-cloud-init/setup-disks.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      LOG_FILE="/var/log/setup-disks.log"
      exec > >(tee -a $LOG_FILE) 2>&1  # Redirect stdout and stderr to log file

      echo "Starting dynamic disk setup..." >> $LOG_FILE

      # Loop over the expected disk names (assuming nvme devices)
      for disk_number in {1..10}; do
        device="/dev/nvme$${disk_number}n1"
        mount_point="/data$${disk_number}"

        # Check if the device exists
        if [ -b "$device" ]; then
          echo "Found device $device" >> $LOG_FILE

          # Check if the disk is already formatted
          if ! blkid "$device"; then
            echo "Formatting $device as XFS" >> $LOG_FILE
            mkfs.xfs "$device"
          fi

          # Create mount point, persist it across stop/start, and mount the disk
          mkdir -p "$mount_point"
          uuid=$(blkid -s UUID -o value "$device")
          if [ -n "$uuid" ] && ! grep -q "$uuid" /etc/fstab; then
            echo "UUID=$uuid $mount_point xfs defaults,nofail 0 2" >> /etc/fstab
          fi
          echo "Mounting $device at $mount_point" >> $LOG_FILE
          mountpoint -q "$mount_point" || mount "$device" "$mount_point"
          chown ${default_username}:${default_username} "$mount_point"
          chmod 777 "$mount_point"
        else
          echo "Device $device not found, skipping" >> $LOG_FILE
        fi
      done

packages:
  - jq
  - xfsprogs

# Execute setup scripts (final stage: the default user exists by now)
runcmd:
  - /var/lib/launcher-cloud-init/setup-hosts.sh
  - /var/lib/launcher-cloud-init/setup-disks.sh
  - install -d -m 0700 -o ${default_username} -g ${default_username} /home/${default_username}/.ssh
  - install -m 0600 -o ${default_username} -g ${default_username} /var/lib/launcher-cloud-init/cluster-ssh-config /home/${default_username}/.ssh/config
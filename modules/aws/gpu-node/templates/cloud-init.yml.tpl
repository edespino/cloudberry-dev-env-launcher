#cloud-config
# gpu-node: hostname, optional extra authorized keys for the default user, and
# optionally the Ollama listen address. Nothing is installed here; the GPU image
# ships the driver and Ollama, the plain agentic image gets them by hand.
hostname: "${hostname}"
fqdn: "${hostname}"
manage_etc_hosts: localhost
%{ if length(authorized_keys) > 0 ~}

# Extra public keys for the default user (for example the parent host cdw), so
# a rebuilt node trusts them from first boot.
ssh_authorized_keys:
%{ for key in authorized_keys ~}
  - "${key}"
%{ endfor ~}
%{ endif ~}
%{ if ollama_bind == "all" ~}

# Ollama listens on all interfaces. Reachability is bounded by the security
# groups: the parent SG (all TCP inside the VPC) and, when configured, the
# sidecar's ollama SG (11434 from approved CIDRs). Harmless on an image without
# Ollama: the drop-in is inert and try-restart is a no-op.
write_files:
  - path: /etc/systemd/system/ollama.service.d/override.conf
    permissions: "0644"
    content: |
      [Service]
      Environment="OLLAMA_HOST=0.0.0.0:11434"

runcmd:
  - systemctl daemon-reload
  - systemctl try-restart ollama.service || true
%{ endif ~}

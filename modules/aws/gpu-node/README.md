# gpu-node

One stoppable, on-demand NVIDIA L4 EC2 instance (g6.2xlarge by default) attached to an
existing environment created by `modules/aws/database-cluster`. The module creates the
instance and an SSM-only IAM role. It creates no VPC, subnet, security group, key pair,
EIP, load balancer, or DNS.

## What it creates

| Resource | Name |
|---|---|
| `aws_instance.this` | `<name_prefix>-<node_name>` |
| `aws_iam_role.this` | `<name_prefix>-<node_name>-ssm` (AmazonSSMManagedInstanceCore only) |
| `aws_iam_instance_profile.this` | `<name_prefix>-<node_name>-ssm` |
| `aws_iam_role_policy_attachment.ssm_core` | |
| `aws_security_group.ollama[0]` (only with `ollama_client_cidrs`) | `<name_prefix>-<node_name>-ollama-*` |

## What it borrows from the parent (read-only)

Subnet, security group, and key pair are passed in as IDs. The recommended caller
(`environments/gpu-node-sample`, scaffolded by `bin/gpu-node`) resolves them from the
parent's tags at plan time:

| Parent resource | Handle set by `database-cluster` |
|---|---|
| VPC | tag `Name = <prefix>-vpc` |
| Subnet | tag `Name = <prefix>-public-subnet` |
| Security group | tag `Name = <prefix>-sg` |
| Key pair | `key_name = <prefix>-generated_key` |

`expected_subnet_id` is an optional guard: when set, the plan fails unless the resolved
subnet matches. Feed it from an independent source (the parent's local state) so a wrong
tag lookup fails at plan.

## Design constraints

- **x86_64 only.** The g6 family has no arm64 variant. Do not pass an arm64 AMI.
- **On-demand only.** No spot. The instance is stopped and started outside Terraform.
- **`ignore_changes = [ami]`.** A newer AMI never rebuilds the node; the root volume holds
  model weights. Rebuild deliberately with `terraform apply -replace=...aws_instance.this`.
- **Ollama exposure is opt-in.** Default `ollama_bind = "loopback"`: Ollama stays on 127.0.0.1
  and is reached via `ssh -L 11434:127.0.0.1:11434`. `ollama_bind = "all"` writes a systemd
  drop-in through cloud-init so Ollama listens on 0.0.0.0; inside the VPC the parent SG already
  allows all TCP, so cdw can then use `http://<private-ip>:11434`. `ollama_client_cidrs` (IPv4,
  never 0.0.0.0/0) additionally creates a sidecar-owned SG for 11434/tcp from those CIDRs, attached
  next to the parent's SG, which is never modified. Ollama has no authentication; keep the list to
  known /32s.
- **Pairing with the parent host.** `authorized_ssh_public_keys` adds public keys (for example cdw's
  `id_ed25519.pub`) to the default user at boot, so a rebuilt node trusts cdw without re-pairing. The
  sidecar's `lpair` alias collects the key and writes cdw's side (`/etc/hosts`, `Host gpu`).
- **Cloud-init installs nothing.** Hostname plus the optional Ollama drop-in. Drivers and Ollama
  come from the GPU image (`agentic-packer-ubuntu26-gpu-*`) or are installed by hand on the plain
  agentic image.
- **Root volume is 200 GiB gp3 by default** (minimum 100), sized for a working set of Q4 models
  next to the roughly 15 GiB image. Growing later is an in-place resize; shrinking needs a rebuild.
- **Root volume is unencrypted by default**, matching `database-cluster`. Set
  `root_volume_encrypted = true` to change that.
- **Public IP changes on every stop/start.** There is no EIP, matching the parent pattern.
- **Private IP survives stop/start but not a rebuild** unless `private_ip` pins it. Pin an unused
  address inside the parent subnet (not the first four or the last, which AWS reserves) so cdw's
  `/etc/hosts`, SSH config, and the Ollama URL stay valid across `-replace`. Pass
  `subnet_cidr_block` too and the plan rejects an address outside the subnet.

## Lifecycle coupling with the parent

Destroy the GPU node before destroying the parent environment. If the parent is destroyed
first, AWS refuses to delete the subnet and security group while the GPU instance's network
interface exists, so the parent destroy stops with a dependency violation rather than
orphaning anything.

## Example

```hcl
module "gpu_node" {
  source = "../../modules/aws/gpu-node"

  name_prefix        = "eespino-synx-ubuntu26-arm64-agentic"
  node_name          = "gpu-l4"
  hostname           = "gpu"
  ami                = var.gpu_ami            # x86_64
  instance_type      = "g6.2xlarge"
  subnet_id          = data.aws_subnet.parent.id
  security_group_id  = data.aws_security_group.parent.id
  key_name           = data.aws_key_pair.parent.key_name
  expected_subnet_id = var.parent_subnet_id  # from the parent's state, via .envrc
}
```

## Outputs

`name`, `instance_id`, `private_ip`, `public_ip`, `availability_zone`, `iam_role_name`,
`ssm_start_session`, and, when enabled, `ollama_security_group_id`, `ollama_vpc_url`,
`ollama_public_url` (null otherwise).

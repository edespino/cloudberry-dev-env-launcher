# OS Selector Configuration

This directory contains the OS configuration for the `os-selector` script. Configuration is defined in YAML files parsed with `yq`.

## Configuration Loading

The script loads **all** files matching `config/os-config-*.yaml`:

1. Matching files are sorted alphabetically for a consistent loading order
2. Each file's `os_options` entries are merged into the combined option set
3. If no matching files exist, the script exits with an error
4. If the same group name appears in more than one file, the script exits with a duplicate-group error

**Requirements**: `yq` command must be installed (`brew install yq`). There is no bash-format fallback — YAML is the only supported format.

Set `DEBUG=1` to see which files are loaded and how many options/groups result:

```bash
DEBUG=1 ./bin/os-selector
```

## File Naming

Only files named `os-config-*.yaml` are loaded. This makes it easy to split configuration across multiple files:

```
config/
├── os-config-base.yaml       # Loaded
├── os-config-custom.yaml     # Loaded (if you create it)
├── os-config.yaml.example-extended   # NOT loaded (doesn't match pattern)
└── os-config.sh.example      # NOT loaded (legacy example only)
```

To add your own options without editing the base file, create a new file such as `config/os-config-custom.yaml` with its own `os_options` section and distinct group names.

## Configuration Format

```yaml
os_options:
  aws-amazon:
    name: "Amazon Linux 2023"
    group: "Base AMIs"
    ami_owner: "137112412989"
    ami_filter: "al2023-ami-minimal-2023.*-kernel-6.12-x86_64"
    username: "ec2-user"
    dir_name: "amazon-linux-2023"

  cbdb-build-rocky9:
    name: "Rocky Linux 9 - Cloudberry build"
    group: "Cloudberry Packer custom AMIs"
    ami_owner: "703671893074"
    ami_filter: "cloudberry-packer-build-rocky9-*"
    username: "rocky"
    dir_name: "rl9-cbdb-build"
```

## Key Naming

You can use any key names in your configuration files:

- **Numeric keys**: `"1"`, `"2"`, `"3"` (traditional, still supported)
- **Descriptive keys**: `amazon`, `rocky9`, `ubuntu-lts` (recommended for clarity)
- **Mixed approach**: Combine both as needed

**User Experience**: Regardless of key names, users always select options by number (1, 2, 3...) in the interactive menu.

**Benefits of Descriptive Keys**:
- Easier to understand and maintain config files
- Self-documenting configuration
- Better for team collaboration
- No need to remember what "option 7" means

## Required Fields

Each OS option must have all six fields. The script validates every field at load time and exits with an error naming the config file and key if any field is missing, empty, or `null`:

- **`name`**: Display name shown in menu
- **`group`**: Group name for organizing options in the display (e.g., "Base AMIs", "Cloudberry Packer custom AMIs")
- **`ami_owner`**: AWS account ID that owns the AMI
- **`ami_filter`**: AMI name pattern for AWS filtering
- **`username`**: Default SSH username for the OS
- **`dir_name`**: Environment directory name

## Grouping Options

The `group` field organizes OS options into logical sections in the interactive menu:

```
Available Operating Systems:

Cloudberry Packer custom AMIs:
  [1] Rocky Linux 9 - Cloudberry build (rl9-cbdb-build)
  [2] Ubuntu 22.04 - Cloudberry build (ubuntu22-cbdb-build)

Base AMIs:
  [3] Amazon Linux 2023 (al2023-base)
  [4] Rocky Linux 9 (rl9-base)
```

**Benefits:**
- Clear visual separation between custom and base images
- Easier to find the right OS for your needs
- Groups appear in order of first occurrence
- Flexible - you can define any group names

**Note**: A group name may only be defined in one config file. Duplicate group names across files cause the script to exit with an error, so each additional config file should use its own group names.

### Cloudberry Packer Custom AMIs

The "Cloudberry Packer custom AMIs" group contains pre-configured development images provided by **Synx Data Labs** (AWS Account ID: `703671893074`) in the **us-west-2** region. These images include:
- Pre-installed Cloudberry Database dependencies
- Optimized build toolchain and development tools
- Configured users and permissions for immediate development

**Note**: Access to these custom AMIs requires appropriate AWS permissions to the Synx Data Labs account.

## Installing yq

```bash
# macOS
brew install yq

# Linux
sudo apt install yq    # Ubuntu/Debian
sudo yum install yq     # CentOS/RHEL/Rocky
```

## Common AMI Information

| OS | Owner ID | Example Filter | Username |
|---|---|---|---|
| Amazon Linux 2023 | 137112412989 | `al2023-ami-minimal-2023.*-kernel-6.12-x86_64` | ec2-user |
| CentOS Stream 9 | 125523088429 | `CentOS-Stream-ec2-9-*x86_64*` | centos |
| Fedora | 125523088429 | `Fedora-Cloud-Base-*-hvm-x86_64-*` | fedora |
| Debian | 679593333241 | `debian-*-amd64-*` | admin |
| Ubuntu | 099720109477 | `*ubuntu-*-amd64-*` | ubuntu |
| Rocky Linux | 679593333241 | `Rocky-*-EC2-Base-*x86_64*` | rocky |

## Testing Your Configuration

After modifying any config file:

```bash
DEBUG=1 ./bin/os-selector
```

You'll see which files were loaded and the available options.

## Best Practices

1. **Split custom options into their own `os-config-*.yaml` file** instead of editing the base file
2. **Use distinct group names per file** to avoid duplicate-group errors
3. **Test AMI filters** before adding new options
4. **Use descriptive keys** for better maintainability
5. **Document custom changes** with comments
6. **Backup configs** before major modifications

## Troubleshooting

- **yq not found**: Install yq (`brew install yq`)
- **No configuration files found**: Ensure at least one `config/os-config-*.yaml` file exists
- **Missing required field error**: The named key in the named file is missing one of the six required fields
- **Duplicate group name error**: The same `group` value appears in two config files - rename one
- **YAML syntax error**: Validate with `yq eval . config/os-config-base.yaml`
- **AMI not found**: Test filter with AWS CLI
- **SSH fails**: Verify username matches AMI default

## GPU Node Images (`gpu-config-*.yaml`)

`bin/gpu-node` scaffolds a GPU sidecar next to an existing environment and picks
its AMI from `config/gpu-config-*.yaml` first, then from the x86_64 entries of
`config/os-config-*.yaml`. The different prefix is deliberate: `os-selector`
loads only `os-config-*.yaml`, so GPU images are never offered for database
nodes and no os-selector change is needed.

Entries use the same six fields as `os-config-*.yaml` plus one optional field:

| Field | Values | Meaning |
|-------|--------|---------|
| `ami_match` | `name` (default) | newest AMI whose **name** matches `ami_filter` |
| | `passed-tag` | newest AMI whose **Name tag** matches `<ami_filter>-PASSED` |

The image factory records PASSED/FAILED on the AMI's Name tag and never renames
the AMI, so a name-based "latest" can select a build that failed its tests. GPU
images use `passed-tag`. Example:

```yaml
os_options:
  ubuntu26-gpu:
    name: "Ubuntu 26.04 - Agentic GPU (NVIDIA L4 driver, nvidia-smi, nvtop, Ollama)"
    group: "Agentic - GPU Packer AMIs"
    ami_owner: "<image-factory account>"
    ami_filter: "agentic-packer-ubuntu26-gpu-*"
    ami_match: "passed-tag"
    username: "ubuntu"
    dir_name: "ubuntu26-gpu"
```

## File Structure

```
config/
├── README.md                          # This documentation
├── os-config-base.yaml                # Base configuration (loaded by os-selector and bin/gpu-node)
├── gpu-config-agentic.yaml            # GPU node images (loaded by bin/gpu-node only)
├── os-config.yaml.example-extended    # Extended YAML example (not loaded)
└── os-config.sh.example               # Legacy bash example (not loaded)
```

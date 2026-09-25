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

  ubuntu26-agentic-eng:
    name: "Ubuntu 26.04 - Agentic (engineering account)"
    group: "Agentic - Engineering Account"
    ami_owner: "${LAUNCHER_ENG_ACCOUNT_ID}"
    ami_filter: "agentic-packer-ubuntu26-2*"
    username: "ubuntu"
    dir_name: "ubuntu26-agentic-eng"
    sso_profile: "${LAUNCHER_ENG_SSO_PROFILE}"
    access_mode: "ssm"
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

Agentic - Engineering Account:
  [1] Ubuntu 26.04 arm64 - Agentic (engineering account) (ubuntu26-arm64-agentic-eng)
  [2] Ubuntu 26.04 - Agentic (engineering account) (ubuntu26-agentic-eng)

Base AMIs:
  [3] Amazon Linux 2023 (al2023-base)
  [4] Rocky Linux 9 (rl9-base)
```

**Benefits:**
- Clear visual separation between custom and base images
- Easier to find the right OS for your needs
- Groups appear in order of first occurrence
- Flexible - you can define any group names

**Account-specific values**: AWS account IDs and SSO profile names are never
committed. `ami_owner` and `sso_profile` may be written as `"${VAR}"`; the
selector resolves them from `.envrc.local` at the repo root (gitignored; copy
`.envrc.example`). An entry whose variable is unset is hidden from the menu.
Public vendor owners (Canonical, Rocky, Amazon) stay literal.

**Note**: A group name may only be defined in one config file. Duplicate group names across files cause the script to exit with an error, so each additional config file should use its own group names.

### Custom AMIs

The launcher lists only custom images built by `cloudberry-image-factory` in the
engineering account (`config/os-config-engineering.yaml` for database nodes,
`config/gpu-config-engineering.yaml` for GPU sidecars): agentic `ubuntu26`
(x86_64), `ubuntu26-arm64` and `ubuntu26-gpu`. Their owner and SSO profile come
from `.envrc.local` (`LAUNCHER_ENG_ACCOUNT_ID`, `LAUNCHER_ENG_SSO_PROFILE`).

The **cloudberry** (rocky9, rocky10) images and the other custom families are
not built in the engineering account yet. Build one on demand with
`cloudberry-image-factory` as a local build
(`AWS_PROFILE="$LAUNCHER_ENG_SSO_PROFILE"`), then add its entry back with
`ami_owner: "${LAUNCHER_ENG_ACCOUNT_ID}"`, the engineering `sso_profile`, and
`access_mode: "ssm"`. Stock vendor images (Base AMIs) need no build.

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
  ubuntu26-gpu-eng:
    name: "Ubuntu 26.04 - Agentic GPU (engineering account)"
    group: "Agentic - GPU (engineering account)"
    ami_owner: "${LAUNCHER_ENG_ACCOUNT_ID}"
    ami_filter: "agentic-packer-ubuntu26-gpu-*"
    ami_match: "passed-tag"
    username: "ubuntu"
    dir_name: "ubuntu26-gpu-eng"
    sso_profile: "${LAUNCHER_ENG_SSO_PROFILE}"
```

`gpu-node` offers an entry only when it fits the parent environment's account:
an entry with `sso_profile` only for parents on that profile; a `passed-tag`
entry without one only for parents whose profile no entry claims (Name tags do
not cross accounts); any other name-match entry for every parent.

## File Structure

```
config/
├── README.md                          # This documentation
├── os-config-base.yaml                # Stock vendor images (loaded by os-selector and bin/gpu-node)
├── os-config-engineering.yaml         # Custom images built in the engineering account
├── gpu-config-engineering.yaml        # GPU node images (loaded by bin/gpu-node only)
├── os-config.yaml.example-extended    # Extended YAML example (not loaded)
└── os-config.sh.example               # Legacy bash example (not loaded)
```

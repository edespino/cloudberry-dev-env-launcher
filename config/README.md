# OS Selector Configuration

This directory contains the OS configuration for the `os-selector` script. The configuration supports both YAML (recommended) and Bash formats for maximum flexibility.

## Configuration Formats

### YAML Format (Recommended)

**File**: `os-config.yaml`

Clean, structured format using descriptive keys:

```yaml
os_options:
  aws-amazon:
    name: "Amazon Linux 2023"
    ami_owner: "137112412989"
    ami_filter: "al2023-ami-minimal-2023.*-kernel-6.12-x86_64"
    username: "ec2-user"
    dir_name: "amazon-linux-2023"
    
  centos-stream:
    name: "CentOS Stream 9"
    ami_owner: "125523088429"
    ami_filter: "CentOS-Stream-ec2-9-*x86_64*"
    username: "centos"
    dir_name: "centos-stream-9"
```

**Requirements**: `yq` command must be installed (`brew install yq`)

### Bash Format (Legacy)

**File**: `os-config.sh`

Traditional bash associative arrays with descriptive keys:

```bash
OS_OPTIONS=(
    ["aws-amazon"]="Amazon Linux 2023"
    ["centos-stream"]="CentOS Stream 9"
)
AMI_OWNERS=(
    ["aws-amazon"]="137112412989"
    ["centos-stream"]="125523088429"
)
# ... other arrays
```

## Configuration Loading Priority

The script loads only ONE config file with this priority:

1. **YAML first**: `config/os-config.yaml` (recommended)
2. **Bash second**: `config/os-config.sh` (legacy)
3. **Error**: Exit with helpful message if none found

**⚠️ Multiple Config Warning**: If both config files exist, the script will warn you and use YAML. This prevents conflicts and confusion.

## Three Ways to Customize

### 1. EXTEND Defaults (Add New Options)

**YAML:**
```yaml
os_options:
  # ... existing defaults 1-8 ...
  "9":
    name: "Fedora 39"
    ami_owner: "125523088429"
    ami_filter: "Fedora-Cloud-Base-39-*-gp3-hvm-x86_64-*"
    username: "fedora"
    dir_name: "fedora-39"
```

**Bash:**
```bash
# Add to existing arrays
OS_OPTIONS["9"]="Fedora 39"
AMI_OWNERS["9"]="125523088429"
# ... etc
```

### 2. MODIFY Specific Options

**YAML:**
```yaml
os_options:
  "1":
    name: "Amazon Linux 2023 (Custom)"
    ami_owner: "137112412989"
    ami_filter: "al2023-ami-minimal-2023.6.*-kernel-6.12-x86_64"
    username: "ec2-user"
    dir_name: "amazon-linux-2023-custom"
```

**Bash:**
```bash
OS_OPTIONS["1"]="Amazon Linux 2023 (Custom)"
AMI_FILTERS["1"]="al2023-ami-minimal-2023.6.*-kernel-6.12-x86_64"
```

### 3. COMPLETELY OVERRIDE All Defaults

**YAML:** Simply replace the entire `os_options` section
**Bash:** Use `unset` then redefine arrays

## Example Files Provided

| File | Description | Status |
|------|-------------|---------|
| `os-config.yaml` | Default configuration (8 OS options, descriptive keys) | **Active** |
| `os-config.yaml.example-extended` | Extended set (12 OS options, descriptive keys) | Example |
| `os-config.sh.example` | Bash format with descriptive keys | Example |

**Note**: Only `os-config.yaml` is active by default. Example files need to be copied/renamed to become active.

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

Each OS option must have all five fields:

- **`name`**: Display name shown in menu
- **`ami_owner`**: AWS account ID that owns the AMI
- **`ami_filter`**: AMI name pattern for AWS filtering  
- **`username`**: Default SSH username for the OS
- **`dir_name`**: Environment directory name

## Alternative Configuration Files

Set environment variables to use different files:

```bash
# Use different YAML file
export CUSTOM_CONFIG_YAML="/path/to/custom.yaml"

# Use different Bash file  
export CUSTOM_CONFIG_BASH="/path/to/custom.sh"

./bin/os-selector
```

## Installing yq (for YAML support)

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
./bin/os-selector
```

You'll see which format was loaded and available options.


## Best Practices

1. **Use YAML format** for new configurations (cleaner syntax)
2. **Keep only one active config** to avoid conflicts
3. **Test AMI filters** before adding new options
4. **Use descriptive keys** for better maintainability
5. **Document custom changes** with comments
6. **Backup configs** before major modifications

## Avoiding Configuration Conflicts

**Problem**: Multiple config files can cause confusion about which is being used.

**Solution**: The script now:
- **Warns you** if multiple config files exist
- **Shows priority order**: YAML > JSON > Bash
- **Uses only the highest priority** file found

**Best Practice**: Keep only one active config file:
```bash
# Good: Only one active config
ls config/
├── os-config.yaml              # Active
├── os-config.json.example      # Example only
└── os-config.sh.example        # Example only

# Avoid: Multiple active configs
├── os-config.yaml    # ⚠️ Both active - causes warning
├── os-config.sh      # ⚠️ Both active - causes warning
```

## Troubleshooting

- **yq not found**: Install yq or use bash format fallback
- **YAML syntax error**: Validate with `yq eval . config.yaml`
- **Options not appearing**: Check all required fields present
- **AMI not found**: Test filter with AWS CLI
- **SSH fails**: Verify username matches AMI default

## File Structure

```
config/
├── README.md                              # This documentation
├── os-config.yaml                         # YAML config (recommended)
├── os-config.yaml.example-minimal         # Minimal YAML example
├── os-config.yaml.example-extended        # Extended YAML example
├── os-config.sh                          # Bash config (fallback)
└── os-config.sh.example-complete-override # Bash override example
```

The configuration system now supports both modern YAML format and traditional bash, with automatic fallback for maximum compatibility.
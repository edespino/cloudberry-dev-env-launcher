#!/usr/bin/env bash
# Shared config helpers for bin/os-selector and bin/gpu-node.
#
# Account-specific values (AWS account IDs, SSO profiles, owner email) are
# never committed. They live in the gitignored .envrc.local at the repo root
# (see .envrc.example); config/*.yaml refers to them as "${VAR}".

# Source <repo-root>/.envrc.local when present.
load_launcher_local_env() {
    local repo_root="$1"
    if [[ -f "$repo_root/.envrc.local" ]]; then
        # shellcheck disable=SC1091
        source "$repo_root/.envrc.local"
    fi
}

# Resolve a whole-value "${VAR}" config reference from the environment.
# Prints the value unchanged when it is not a reference; returns 1 when the
# referenced variable is unset or empty.
expand_config_value() {
    local value="$1"
    if [[ "$value" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
        local name="${BASH_REMATCH[1]}"
        [[ -n "${!name:-}" ]] || return 1
        printf '%s\n' "${!name}"
    else
        printf '%s\n' "$value"
    fi
}

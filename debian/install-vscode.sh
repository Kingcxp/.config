#!/usr/bin/env bash
set -Eeuo pipefail

VSCODE_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

vscode_die() { printf 'Error: %s\n' "$*" >&2; exit 2; }
vscode_read_list() { awk 'NF && $1 !~ /^#/ { sub(/\r$/, "", $1); print $1 }' "$1"; }

vscode_help() {
    cat <<'EOF'
Usage: bash install-vscode.sh [--bundle NAME ...] [--profile NAME] [--dry-run]
       bash install-vscode.sh --list

Default: common extensions + research, in the default VS Code profile.
--bundle core installs only the common extensions. Repeat --bundle to combine.
--profile NAME targets an existing profile. To create an empty one first:
  code --profile NAME --new-window --wait
Close that new window, then run this installer with --profile NAME.
This installs extensions; it never disables/removes existing ones or copies settings.
Dependencies/extension packs can add more extensions than the explicit list.
EOF
}

vscode_list() {
    local manifest
    printf 'core: common language, theme, configuration and Markdown support\n'
    for manifest in "$VSCODE_DIR"/vscode/extensions/*.txt; do
        printf '%s: %s\n' "$(basename "$manifest" .txt)" "$(head -n 1 "$manifest" | sed 's/^# *//; s/\r$//')"
    done
}

vscode_check_profile() {
    local profile="$1"
    [[ -n "$profile" ]] || return 0
    # Extension-management CLI requires an existing profile, unlike opening a window.
    if ! code --profile "$profile" --list-extensions >/dev/null; then
        printf 'Cannot read VS Code profile %q. Create/open it first, then close the window:\n' "$profile" >&2
        printf '  %q ' code --profile "$profile" --new-window --wait >&2
        printf '\nThen rerun this installer.\n' >&2
        return 2
    fi
}

vscode_install() {
    local profile="$1" extension
    shift
    local code_args=() failures=()
    [[ -z "$profile" ]] || code_args=(--profile "$profile")
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/myconfig-debian"
    mkdir -p "$state_dir"
    : >"$state_dir/failed-vscode-extensions.txt"
    for extension in "$@"; do
        if ! code "${code_args[@]}" --install-extension "$extension"; then failures+=("$extension"); fi
    done
    if (( ${#failures[@]} )); then
        printf '%s\n' "${failures[@]}" | tee "$state_dir/failed-vscode-extensions.txt" >&2
        printf 'Some extensions failed. See %s/failed-vscode-extensions.txt\n' "$state_dir" >&2
        return 1
    fi
    printf 'All requested extensions installed. Existing extensions and settings were preserved.\n'
}

vscode_main() {
    local profile="" dry_run=false bundle extension manifest
    local bundles=() manifests=("$VSCODE_DIR/vscode-extensions.txt") extensions=() code_args=()
    local -A seen=()
    while (( $# )); do
        case "$1" in
            --bundle)
                (( $# >= 2 )) && [[ -n "$2" ]] || vscode_die '--bundle requires a name'
                bundles+=("$2"); shift 2 ;;
            --profile)
                (( $# >= 2 )) && [[ -n "$2" && "$2" != --* ]] || vscode_die '--profile requires a name'
                profile="$2"; shift 2 ;;
            --dry-run) dry_run=true; shift ;;
            --list) [[ "$#" == 1 ]] || vscode_die 'Use --list on its own'; vscode_list; return ;;
            --help|-h) vscode_help; return ;;
            *) vscode_die "Unknown option: $1" ;;
        esac
    done
    if (( ${#bundles[@]} == 0 )); then bundles=(research); fi
    for bundle in "${bundles[@]}"; do
        [[ "$bundle" =~ ^[a-z][a-z0-9-]*$ ]] || vscode_die "Invalid bundle name: $bundle"
        [[ "$bundle" != core ]] || continue
        manifest="$VSCODE_DIR/vscode/extensions/$bundle.txt"
        [[ -s "$manifest" ]] || vscode_die "Unknown bundle: $bundle (see --list)"
        manifests+=("$manifest")
    done
    for manifest in "${manifests[@]}"; do
        [[ -s "$manifest" ]] || vscode_die "Missing extension manifest: $manifest"
        while IFS= read -r extension; do
            [[ "$extension" =~ ^[A-Za-z0-9-]+\.[A-Za-z0-9-]+$ ]] || vscode_die "Invalid extension ID: $extension"
            extension="${extension,,}"
            if [[ -z "${seen[$extension]:-}" ]]; then
                seen["$extension"]=1
                extensions+=("$extension")
            fi
        done < <(vscode_read_list "$manifest")
    done
    [[ -z "$profile" ]] || code_args=(--profile "$profile")
    printf 'VS Code: %s explicit extension requests; profile: %s\n' "${#extensions[@]}" "${profile:-default}"
    if [[ "$dry_run" == true ]]; then
        for extension in "${extensions[@]}"; do
            printf '%q ' code "${code_args[@]}" --install-extension "$extension"
            printf '\n'
        done
        return
    fi
    [[ "$EUID" -ne 0 ]] || vscode_die 'Run as your normal user, without sudo.'
    command -v code >/dev/null || vscode_die 'code is not in PATH; install VS Code first.'
    vscode_check_profile "$profile"
    vscode_install "$profile" "${extensions[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then vscode_main "$@"; fi

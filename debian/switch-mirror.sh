#!/usr/bin/env bash
set -Eeuo pipefail
MIRROR_SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

mirror_apply() {
    local mirror="$1" backup
    backup="$(sudo python3 "$MIRROR_SCRIPT_DIR/lib/apt-sources.py" --switch "$mirror")" || return 2
    printf 'Checking selected Debian mirror; APT source backup: %s\n' "$backup"
    # Check this archive independently of unrelated vendor availability. Keep other list indexes.
    if ! sudo apt-get update -o APT::Update::Error-Mode=any -o Acquire::Retries=1 \
        -o Acquire::https::Timeout=20 -o Acquire::http::Timeout=20 \
        -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/myconfig-debian.sources \
        -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0; then
        printf 'Mirror check failed; restoring previous APT sources.\n' >&2
        sudo python3 "$MIRROR_SCRIPT_DIR/lib/apt-sources.py" --restore "$backup" || return 2
        return 1
    fi
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/myconfig-debian"
    mkdir -p "$state_dir"
    printf '%s\n' "$mirror" >"$state_dir/mirror"
    printf 'Debian APT mirror selected: %s\n' "$mirror"
}

mirror_main() {
    local mirror="${1:-}" dry_run=false
    case "$mirror" in
        --help|-h|'') printf 'Usage: bash switch-mirror.sh official|nju [--dry-run]\nSwitch Debian 13 APT archives only; vendor repositories and Homebrew are preserved.\n'; return ;;
        official|nju) shift ;;
        *) printf 'Unknown mirror: %s\n' "$mirror" >&2; return 2 ;;
    esac
    if [[ "${1:-}" == --dry-run ]]; then dry_run=true; shift; fi
    (( $# == 0 )) || { printf 'Unexpected mirror option\n' >&2; return 2; }
    if [[ "$dry_run" == true ]]; then
        printf 'Select %s for trixie, updates, security and backports; back up/disable old Debian/CD-ROM entries, retain vendors.\n' "$mirror"
        return
    fi
    [[ "$EUID" -ne 0 ]] || { printf 'Run as your normal user, without sudo.\n' >&2; return 2; }
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == debian && "${VERSION_CODENAME:-}" == trixie ]] || { printf 'Requires Debian 13 Trixie.\n' >&2; return 2; }
    if ! command -v python3 >/dev/null || ! command -v sudo >/dev/null; then
        printf 'Requires python3 and sudo.\n' >&2; return 2
    fi
    [[ -r /usr/share/keyrings/debian-archive-keyring.gpg ]] || { printf 'Missing Debian archive keyring.\n' >&2; return 2; }
    mirror_apply "$mirror"
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then mirror_main "$@"; fi

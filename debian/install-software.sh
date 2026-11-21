#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR=""
FAILURES=()
FINISHED=false
MANUAL_SHOWN=false
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/myconfig-debian"

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 2; }
read_list() { awk 'NF && $1 !~ /^#/ { sub(/\r$/, "", $1); print $1 }' "$SCRIPT_DIR/$1"; }
cleanup() { if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then rm -rf -- "$WORK_DIR"; fi; }
on_exit() {
    local status="$1"
    if (( status )) && [[ -n "$WORK_DIR" ]]; then
        if [[ ! -s "$STATE_DIR/failed-packages.txt" ]]; then
            printf 'Installer stopped early (exit %s). Inspect install.log and rerun.\n' "$status" >"$STATE_DIR/failed-packages.txt"
        fi
        printf '\nInstallation incomplete. Log: %s/install.log\n' "$STATE_DIR" >&2
        if [[ "$MANUAL_SHOWN" == false ]]; then manual; fi
    fi
    cleanup
    if (( status )) && [[ "$FINISHED" == false && -n "$WORK_DIR" ]]; then exit 2; fi
}
trap 'on_exit "$?"' EXIT

manual() { cat "$SCRIPT_DIR/MANUAL.md"; MANUAL_SHOWN=true; }

plan() {
    printf 'Debian 13 Trixie / amd64; current user: %s\n' "${USER:-unknown}"
    printf 'APT: official Debian + Backports + Tailscale + Microsoft (Code/Edge).\n'
    printf 'Steam/Wine: enable i386, contrib, non-free, non-free-firmware.\n'
    local list
    for list in packages.txt packages-backports.txt packages-vendor.txt brew-formulae.txt brew-casks.txt vscode-extensions.txt; do
        printf '\n[%s]\n' "$list"
        read_list "$list" | tr '\n' ' '
        printf '\n'
    done
    printf '\nOther software and post-install steps:\n'
    manual
}

write_source() {
    local target="$1" source="$2"
    if [[ -e "$target" ]] && ! grep -q '^# Managed by myconfig' "$target"; then
        die "Will not overwrite an unmanaged APT source: $target"
    fi
    sudo install -m 0644 "$source" "$target"
}

ensure_vendor() {
    local name="$1" uri="$2" key_url="$3" key_path="$4" ascii="$5"
    if python3 "$SCRIPT_DIR/lib/apt-sources.py" --has "$uri"; then
        return
    fi
    if [[ "$name" == vscode ]] && python3 "$SCRIPT_DIR/lib/apt-sources.py" --has https://packages.microsoft.com/repos/vscode; then
        return
    fi
    say "Adding official signed APT repository: $name"
    curl --fail --location --retry 3 --connect-timeout 20 "$key_url" -o "$WORK_DIR/$name.key"
    if [[ "$ascii" == yes ]]; then
        gpg --batch --yes --dearmor --output "$WORK_DIR/$name.gpg" "$WORK_DIR/$name.key"
    else
        cp -- "$WORK_DIR/$name.key" "$WORK_DIR/$name.gpg"
    fi
    gpg --batch --show-keys "$WORK_DIR/$name.gpg" >/dev/null
    sudo install -m 0644 "$WORK_DIR/$name.gpg" "$key_path"
    printf '%s\n' '# Managed by myconfig Debian installer.' 'Types: deb' \
        "URIs: $uri" "Suites: $([[ "$name" == tailscale ]] && printf trixie || printf stable)" \
        'Components: main' 'Architectures: amd64' "Signed-By: $key_path" >"$WORK_DIR/$name.sources"
    write_source "/etc/apt/sources.list.d/myconfig-$name.sources" "$WORK_DIR/$name.sources"
}

install_apt_set() {
    local list="$1" release="${2:-}" package
    local options=() packages=()
    [[ -z "$release" ]] || options=(-t "$release")
    mapfile -t packages < <(read_list "$list")
    say "APT: $list (${#packages[@]} packages)"
    # Do not silently remove an existing desktop/package to satisfy this list.
    if sudo apt-get install --no-remove -y "${options[@]}" "${packages[@]}"; then
        return
    fi
    say 'Batch failed; retrying each package so one unavailable item cannot hide the rest'
    for package in "${packages[@]}"; do
        if ! sudo apt-get install --no-remove -y "${options[@]}" "$package"; then
            FAILURES+=("APT $package")
        fi
    done
}

install_brew() {
    local brew_path="" candidate package kind list prefix
    if command -v brew >/dev/null; then brew_path="$(command -v brew)"; fi
    for candidate in /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
        if [[ -z "$brew_path" && -x "$candidate" ]]; then brew_path="$candidate"; fi
    done
    if [[ -z "$brew_path" ]]; then
        say 'Installing Homebrew for the current user from the official installer'
        sudo -v
        curl --fail --location --retry 3 --connect-timeout 20 \
            https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$WORK_DIR/homebrew-install.sh"
        # The official installer handles sudo for the prefix; brew itself is never run as root.
        if ! NONINTERACTIVE=1 /bin/bash "$WORK_DIR/homebrew-install.sh"; then
            FAILURES+=("Homebrew bootstrap; all brew packages pending")
            return
        fi
        brew_path=/home/linuxbrew/.linuxbrew/bin/brew
    fi
    [[ -x "$brew_path" ]] || { FAILURES+=("Homebrew executable missing: $brew_path"); return; }
    eval "$("$brew_path" shellenv bash)"
    # Used by the desktop installer's environment files, including a custom prefix.
    "$brew_path" --prefix >"$STATE_DIR/brew-prefix"
    if ! "$brew_path" update; then FAILURES+=("Homebrew update (existing metadata used)"); fi
    export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
    for kind in formula cask; do
        if [[ "$kind" == formula ]]; then list=brew-formulae.txt; else list=brew-casks.txt; fi
        while IFS= read -r package; do
            if "$brew_path" list "--$kind" "$package" >/dev/null 2>&1; then
                printf 'Already installed (brew %s): %s\n' "$kind" "$package"
                continue
            fi
            say "Homebrew $kind: $package"
            if ! "$brew_path" install "--$kind" "$package"; then FAILURES+=("BREW $kind $package"); fi
        done < <(read_list "$list")
    done
    prefix="$("$brew_path" --prefix)"
    export PATH="$prefix/opt/node@22/bin:$PATH"
    fc-cache -f || FAILURES+=("Font cache refresh")
}

install_extensions() {
    local extension
    if ! command -v code >/dev/null; then FAILURES+=("VS Code extensions (code unavailable)"); return; fi
    while IFS= read -r extension; do
        if ! code --install-extension "$extension"; then FAILURES+=("CODE $extension"); fi
    done < <(read_list vscode-extensions.txt)
}

ensure_chinese_locale() {
    if [[ ! -x /usr/sbin/locale-gen ]]; then
        FAILURES+=("Chinese locale generation (locales package unavailable)")
        return
    fi
    if ! grep -Eq '^[[:space:]]*zh_CN\.UTF-8[[:space:]]+UTF-8' /etc/locale.gen; then
        printf '\nzh_CN.UTF-8 UTF-8\n' | sudo tee -a /etc/locale.gen >/dev/null
    fi
    if ! sudo /usr/sbin/locale-gen; then FAILURES+=("Chinese locale generation"); fi
}

main() {
    case "${1:-}" in
        --dry-run) [[ "$#" == 1 ]] || die 'Use one option at a time'; plan; return ;;
        --manual) [[ "$#" == 1 ]] || die 'Use one option at a time'; manual; return ;;
        --help|-h) printf 'Usage: bash install-software.sh [--dry-run | --manual | --help]\nInstalls software only; use install.sh to also deploy the Debian desktop configuration.\n'; return ;;
        '') [[ "$#" == 0 ]] || die 'Unexpected empty argument' ;;
        *) die "Unknown option: $1" ;;
    esac
    [[ "$EUID" -ne 0 ]] || die 'Run as your normal user, without sudo.'
    local manifest
    for manifest in packages.txt packages-backports.txt packages-vendor.txt brew-formulae.txt brew-casks.txt vscode-extensions.txt MANUAL.md lib/apt-sources.py; do
        [[ -s "$SCRIPT_DIR/$manifest" ]] || die "Missing installer file: $manifest"
    done
    command -v apt-get >/dev/null || die 'This script requires Debian 13 apt-get.'
    command -v sudo >/dev/null || die 'Install sudo and grant your user sudo access first.'
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == debian && "${VERSION_CODENAME:-}" == trixie ]] || die "Requires Debian 13 Trixie, detected ${PRETTY_NAME:-unknown}."
    [[ "$(dpkg --print-architecture)" == amd64 ]] || die 'This ThinkBook profile requires amd64.'
    sudo -v
    WORK_DIR="$(mktemp -d)"
    mkdir -p "$STATE_DIR"
    : >"$STATE_DIR/failed-packages.txt"
    exec > >(tee -a "$STATE_DIR/install.log") 2>&1
    # Bootstrap before curl/gpg/python are first used, including on minimal Debian.
    sudo apt-get update -o APT::Update::Error-Mode=any
    sudo apt-get install --no-remove -y ca-certificates curl gnupg python3 git build-essential procps file
    sudo dpkg --add-architecture i386
    python3 "$SCRIPT_DIR/lib/apt-sources.py" >"$WORK_DIR/debian.sources"
    write_source /etc/apt/sources.list.d/myconfig-debian.sources "$WORK_DIR/debian.sources"
    ensure_vendor tailscale https://pkgs.tailscale.com/stable/debian \
        https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg /usr/share/keyrings/tailscale-archive-keyring.gpg no
    ensure_vendor vscode https://packages.microsoft.com/repos/code \
        https://packages.microsoft.com/keys/microsoft.asc /usr/share/keyrings/microsoft.gpg yes
    ensure_vendor edge https://packages.microsoft.com/repos/edge \
        https://packages.microsoft.com/keys/microsoft.asc /usr/share/keyrings/microsoft.gpg yes
    if ! dpkg-query -W -f='${Status}' openssh-server 2>/dev/null | grep -qx 'install ok installed'; then
        # Debian may start sshd from its package post-installation script.
        # Give a new installation key-only defaults before installing the server.
        sudo install -d -m 0755 /etc/ssh/sshd_config.d
        printf '%s\n' '# Managed by myconfig (new OpenSSH installations only).' \
            'PasswordAuthentication no' 'KbdInteractiveAuthentication no' 'PermitRootLogin no' \
            'AuthenticationMethods publickey' >"$WORK_DIR/ssh.conf"
        if [[ ! -e /etc/ssh/sshd_config.d/60-myconfig.conf ]]; then
            sudo install -m 0644 "$WORK_DIR/ssh.conf" /etc/ssh/sshd_config.d/60-myconfig.conf
        fi
    fi
    sudo apt-get update -o APT::Update::Error-Mode=any
    install_apt_set packages.txt
    install_apt_set packages-backports.txt trixie-backports
    install_apt_set packages-vendor.txt
    ensure_chinese_locale
    install_brew
    install_extensions
    manual
    FINISHED=true
    if (( ${#FAILURES[@]} )); then
        printf '%s\n' "${FAILURES[@]}" | tee "$STATE_DIR/failed-packages.txt" >&2
        printf '\nSome installations failed. See %s/failed-packages.txt and rerun this script after fixing the reported errors.\n' "$STATE_DIR" >&2
        return 1
    fi
    say 'All automatic software installations completed; manual/setup items are listed above'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi

#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR=""
FAILURES=()
FINISHED=false
MANUAL_SHOWN=false
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/myconfig-debian"
# Linted separately; no actions are executed on import.
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/desktop-migration.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/configure-system.sh"
MIRROR=official
DESKTOP_MIGRATION=false
DOCKER_PREEXISTING=false

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
    printf 'APT: Debian mirror=%s + Backports + official Tailscale/Microsoft repositories.\n' "$MIRROR"
    printf 'Steam/Wine: enable i386, contrib, non-free, non-free-firmware.\n'
    local list
    for list in packages.txt packages-backports.txt packages-vendor.txt brew-formulae.txt brew-casks.txt; do
        printf '\n[%s]\n' "$list"
        read_list "$list" | tr '\n' ' '
        printf '\n'
    done
    printf '\n[VS Code: common + research; optional bundles: install-vscode.sh --list]\n'
    bash "$SCRIPT_DIR/install-vscode.sh" --dry-run
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
    if ! bash "$SCRIPT_DIR/install-vscode.sh"; then
        FAILURES+=("VS Code extensions (see output and failed-vscode-extensions.txt if present)")
    fi
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
    if ! sudo update-locale LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:en_US \
        LC_ADDRESS=zh_CN.UTF-8 LC_IDENTIFICATION=zh_CN.UTF-8 LC_MEASUREMENT=zh_CN.UTF-8 \
        LC_MONETARY=zh_CN.UTF-8 LC_NAME=zh_CN.UTF-8 LC_NUMERIC=zh_CN.UTF-8 \
        LC_PAPER=zh_CN.UTF-8 LC_TELEPHONE=zh_CN.UTF-8 LC_TIME=zh_CN.UTF-8; then
        FAILURES+=("Set the system-wide Chinese locale")
    fi
    if ! sudo timedatectl set-timezone Asia/Shanghai; then FAILURES+=("Set the system time zone to Asia/Shanghai"); fi
}

main() {
    local dry_run=false
    if [[ -r "$STATE_DIR/mirror" ]]; then IFS= read -r MIRROR <"$STATE_DIR/mirror"; fi
    while (( $# )); do
        case "$1" in
            --mirror) (( $# >= 2 )) || die '--mirror requires official or nju'; MIRROR="$2"; shift 2 ;;
            --desktop-migration) DESKTOP_MIGRATION=true; shift ;;
            --dry-run) dry_run=true; shift ;;
            --manual) manual; return ;;
            --help|-h) printf 'Usage: bash install-software.sh [--mirror official|nju] [--dry-run | --manual]\nInstalls software only. install.sh also deploys the desktop and removes KDE.\n'; return ;;
            *) die "Unknown option: $1" ;;
        esac
    done
    [[ "$MIRROR" == official || "$MIRROR" == nju ]] || die 'Mirror must be official or nju'
    if [[ "$dry_run" == true ]]; then plan; return; fi
    [[ "$EUID" -ne 0 ]] || die 'Run as your normal user, without sudo.'
    local manifest
    for manifest in packages.txt packages-backports.txt packages-vendor.txt brew-formulae.txt brew-casks.txt vscode-extensions.txt vscode/extensions/research.txt install-vscode.sh switch-mirror.sh MANUAL.md lib/apt-sources.py lib/desktop-migration.sh lib/configure-system.sh lib/configure-bluez.py system/environment.d/60-docker-rootless.conf system/modprobe.d/myconfig-v4l2loopback.conf system/modules-load.d/myconfig-v4l2loopback.conf system/ssh/00-myconfig.conf config/.config/docker/daemon.json; do
        [[ -s "$SCRIPT_DIR/$manifest" ]] || die "Missing installer file: $manifest"
    done
    command -v apt-get >/dev/null || die 'This script requires Debian 13 apt-get.'
    command -v sudo >/dev/null || die 'Install sudo and grant your user sudo access first.'
    command -v python3 >/dev/null || die 'Install python3 first (Debian KDE normally includes it).'
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == debian && "${VERSION_CODENAME:-}" == trixie ]] || die "Requires Debian 13 Trixie, detected ${PRETTY_NAME:-unknown}."
    [[ "$(dpkg --print-architecture)" == amd64 ]] || die 'This ThinkBook profile requires amd64.'
    sudo -v
    WORK_DIR="$(mktemp -d)"
    mkdir -p "$STATE_DIR"
    : >"$STATE_DIR/failed-packages.txt"
    exec > >(tee -a "$STATE_DIR/install.log") 2>&1
    if dpkg-query -W -f='${Status}' docker.io 2>/dev/null | grep -qx 'install ok installed'; then
        DOCKER_PREEXISTING=true
    fi
    # Select a working mirror before the first update, including broken old/CD-ROM sources.
    sudo dpkg --add-architecture i386
    bash "$SCRIPT_DIR/switch-mirror.sh" "$MIRROR" || return 2
    sudo apt-get update -o APT::Update::Error-Mode=any
    sudo apt-get install --no-remove -y ca-certificates curl gnupg python3 git build-essential procps file
    ensure_vendor tailscale https://pkgs.tailscale.com/stable/debian \
        https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg /usr/share/keyrings/tailscale-archive-keyring.gpg no
    ensure_vendor vscode https://packages.microsoft.com/repos/code \
        https://packages.microsoft.com/keys/microsoft.asc /usr/share/keyrings/microsoft.gpg yes
    ensure_vendor edge https://packages.microsoft.com/repos/edge \
        https://packages.microsoft.com/keys/microsoft.asc /usr/share/keyrings/microsoft.gpg yes
    sudo apt-get update -o APT::Update::Error-Mode=any
    install_apt_set packages.txt
    if [[ "$DESKTOP_MIGRATION" == true ]]; then
        if ! desktop_power_transition; then FAILURES+=("TLP power-manager transition; retain KDE"); fi
    fi
    install_apt_set packages-backports.txt trixie-backports
    install_apt_set packages-vendor.txt
    ensure_chinese_locale
    configure_system_profile "$DOCKER_PREEXISTING"
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

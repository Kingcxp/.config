#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$SCRIPT_DIR/config"
PACKAGES_FILE="$SCRIPT_DIR/packages.txt"
BACKUP_ROOT=""
ASSET_WORK_DIR=""
APT_SOURCE_DIR="/etc/apt/sources.list.d"

cleanup() {
    if [[ -n "$ASSET_WORK_DIR" && -d "$ASSET_WORK_DIR" ]]; then
        rm -rf -- "$ASSET_WORK_DIR"
    fi
}
trap cleanup EXIT

usage() {
    cat <<'EOF'
Usage: bash install.sh [--dry-run | --help]

Install the Debian 13 Trixie profile, then link its user configuration into
the current user's home directory. Existing files are moved to a dated backup.
EOF
}

say() {
    printf '\n==> %s\n' "$*"
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

for arg in "$@"; do
    case "$arg" in
        --help|-h)
            usage
            exit 0
            ;;
        --dry-run)
            printf 'Debian profile: %s\n' "$SCRIPT_DIR"
            printf 'APT packages: '
            awk 'NF && $1 !~ /^#/ { count++ } END { print count + 0 }' "$PACKAGES_FILE"
            printf 'Hyprland source: official trixie-backports\n'
            printf 'User config target: %s/.config\n' "$HOME"
            exit 0
            ;;
        *)
            die "Unknown option: $arg (use --help)"
            ;;
    esac
done

[[ "$EUID" -ne 0 ]] || die "Run this script as your normal user, without sudo."
[[ -d "$PROFILE_DIR/.config" ]] || die "Missing profile files under $PROFILE_DIR/config."
[[ -r "$PACKAGES_FILE" ]] || die "Missing package list: $PACKAGES_FILE"
command -v sudo >/dev/null || die "sudo is required; install it and grant your account sudo access first."
command -v apt-get >/dev/null || die "This installer requires Debian's apt-get."

# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == debian && "${VERSION_CODENAME:-}" == trixie ]] || \
    die "This profile targets Debian 13 (Trixie). Detected ${PRETTY_NAME:-unknown}."
[[ "$(dpkg --print-architecture)" == amd64 ]] || \
    die "The pinned Yazi package targets amd64; this profile is for the ThinkBook x86_64."

sudo -v

ensure_backports() {
    local source_file
    if { [[ -r /etc/apt/sources.list ]] && grep -Eq '^[[:space:]]*deb(-src)?[[:space:]].*trixie-backports' /etc/apt/sources.list; } || \
        grep -Eq '^[[:space:]]*(deb(-src)?[[:space:]].*trixie-backports|Suites:[[:space:]].*trixie-backports)' \
            "$APT_SOURCE_DIR"/*.list "$APT_SOURCE_DIR"/*.sources 2>/dev/null; then
        return
    fi

    for source_file in \
        "$APT_SOURCE_DIR/myconfig-trixie-backports.sources" \
        "$APT_SOURCE_DIR/myconfig-trixie-backports-2.sources" \
        "$APT_SOURCE_DIR/myconfig-trixie-backports-3.sources"; do
        [[ -e "$source_file" ]] || break
    done
    [[ ! -e "$source_file" ]] || die "Could not choose a new APT source filename."

    say "Adding Debian's signed Trixie Backports source"
    printf '%s\n' \
        'Types: deb' \
        'URIs: https://deb.debian.org/debian' \
        'Suites: trixie-backports' \
        'Components: main' \
        'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg' |
        sudo tee "$source_file" >/dev/null
}

ensure_firmware_archive() {
    local source_file
    if { [[ -r /etc/apt/sources.list ]] && grep -Eq '^[[:space:]]*deb(-src)?[[:space:]].*non-free-firmware' /etc/apt/sources.list; } || \
        grep -Eq '^[[:space:]]*(deb(-src)?[[:space:]].*non-free-firmware|Components:[[:space:]].*non-free-firmware)' \
            "$APT_SOURCE_DIR"/*.list "$APT_SOURCE_DIR"/*.sources 2>/dev/null; then
        return
    fi

    for source_file in \
        "$APT_SOURCE_DIR/myconfig-trixie-firmware.sources" \
        "$APT_SOURCE_DIR/myconfig-trixie-firmware-2.sources" \
        "$APT_SOURCE_DIR/myconfig-trixie-firmware-3.sources"; do
        [[ -e "$source_file" ]] || break
    done
    [[ ! -e "$source_file" ]] || die "Could not choose a new firmware APT source filename."

    say "Enabling Debian's signed firmware archive for Intel laptop hardware"
    printf '%s\n' \
        'Types: deb' \
        'URIs: https://deb.debian.org/debian' \
        'Suites: trixie' \
        'Components: non-free-firmware' \
        'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg' |
        sudo tee "$source_file" >/dev/null
}

ensure_tailscale_archive() {
    local key_file source_file
    if { [[ -r /etc/apt/sources.list ]] && grep -Eq '^[[:space:]]*deb(-src)?[[:space:]].*pkgs.tailscale.com/stable/debian' /etc/apt/sources.list; } || \
        grep -Rqs '^[[:space:]]*deb(-src)?[[:space:]].*pkgs.tailscale.com/stable/debian' "$APT_SOURCE_DIR" 2>/dev/null; then
        return
    fi

    say "Adding Tailscale's official signed Debian repository"
    key_file=/usr/share/keyrings/tailscale-archive-keyring.gpg
    if [[ ! -e "$key_file" ]]; then
        curl -fsSL --retry 3 --retry-all-errors \
            'https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg' |
            sudo tee "$key_file" >/dev/null
    fi
    for source_file in \
        "$APT_SOURCE_DIR/tailscale.list" \
        "$APT_SOURCE_DIR/tailscale-myconfig.list" \
        "$APT_SOURCE_DIR/tailscale-myconfig-2.list" \
        "$APT_SOURCE_DIR/tailscale-myconfig-3.list"; do
        [[ -e "$source_file" ]] || break
    done
    [[ ! -e "$source_file" ]] || die "Could not choose a new Tailscale source filename."
    curl -fsSL --retry 3 --retry-all-errors \
        'https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list' |
        sudo tee "$source_file" >/dev/null
}

install_release_assets() {
    local font_dir yazi_url font_url posh_url
    ASSET_WORK_DIR="$(mktemp -d)"

    say "Installing the pinned upstream Yazi package"
    yazi_url='https://github.com/sxyazi/yazi/releases/download/v26.9.1/yazi-x86_64-unknown-linux-gnu.deb'
    curl -fL --retry 3 --retry-all-errors "$yazi_url" -o "$ASSET_WORK_DIR/yazi.deb"
    printf '%s  %s\n' \
        '331d6247c0a0fd549f14cd599a928a529b8b22eded1bb1f61a518376c7621b45' \
        "$ASSET_WORK_DIR/yazi.deb" | sha256sum --check --status || die "Yazi checksum verification failed."
    sudo apt-get install -y "$ASSET_WORK_DIR/yazi.deb"

    if ! command -v oh-my-posh >/dev/null && [[ ! -e "$HOME/.local/bin/oh-my-posh" ]]; then
        say "Installing the pinned Oh My Posh binary"
        posh_url='https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v32.1.0/posh-linux-amd64'
        curl -fL --retry 3 --retry-all-errors "$posh_url" -o "$ASSET_WORK_DIR/oh-my-posh"
        printf '%s  %s\n' \
            '75d0c69daadd43931a781b36896744a530efff3b769606b9a4cb7e20ab6e7b8b' \
            "$ASSET_WORK_DIR/oh-my-posh" | sha256sum --check --status || die "Oh My Posh checksum verification failed."
        install -Dm755 "$ASSET_WORK_DIR/oh-my-posh" "$HOME/.local/bin/oh-my-posh"
    fi

    say "Installing the pinned JetBrainsMono Nerd Font"
    font_url='https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz'
    curl -fL --retry 3 --retry-all-errors "$font_url" -o "$ASSET_WORK_DIR/JetBrainsMono.tar.xz"
    printf '%s  %s\n' \
        '04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf' \
        "$ASSET_WORK_DIR/JetBrainsMono.tar.xz" | sha256sum --check --status || die "Nerd Font checksum verification failed."
    font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    mkdir -p "$font_dir"
    tar -xJf "$ASSET_WORK_DIR/JetBrainsMono.tar.xz" -C "$font_dir" --wildcards '*.ttf'
    fc-cache -f "$font_dir"
}

backup_existing() {
    local target_path="$1" backup_path
    if [[ -z "$BACKUP_ROOT" ]]; then
        BACKUP_ROOT="$HOME/.local/state/myconfig-debian/backups/$(date +%Y%m%d-%H%M%S)-$$"
        mkdir -p "$BACKUP_ROOT"
    fi
    backup_path="$BACKUP_ROOT/${target_path#"$HOME"/}"
    mkdir -p "$(dirname -- "$backup_path")"
    mv -- "$target_path" "$backup_path"
    printf 'Backed up %s to %s\n' "$target_path" "$backup_path"
}

backup_and_link() {
    local source_path="$1" target_path="$2"
    mkdir -p "$(dirname -- "$target_path")"

    if [[ -L "$target_path" ]] && [[ "$(readlink -f -- "$target_path" 2>/dev/null || true)" == "$(readlink -f -- "$source_path")" ]]; then
        return
    fi

    if [[ -e "$target_path" || -L "$target_path" ]]; then
        backup_existing "$target_path"
    fi

    ln -s -- "$source_path" "$target_path"
}

install_tmux_plugins() {
    local plugin_root="$HOME/.config/tmux/plugins"
    mkdir -p "$plugin_root"

    clone_plugin() {
        local url="$1" target="$2"
        if [[ -d "$target/.git" ]]; then
            return
        fi
        if [[ -e "$target" ]]; then
            printf 'Keeping existing tmux plugin path: %s\n' "$target"
            return
        fi
        git clone --depth 1 "$url" "$target"
    }

    mkdir -p "$plugin_root/catppuccin"
    clone_plugin 'https://github.com/catppuccin/tmux.git' "$plugin_root/catppuccin/tmux"
    clone_plugin 'https://github.com/tmux-plugins/tmux-cpu.git' "$plugin_root/tmux-plugins/tmux-cpu"
    clone_plugin 'https://github.com/tmux-plugins/tmux-battery.git' "$plugin_root/tmux-plugins/tmux-battery"
}

link_tree() {
    local source_dir="$1" target_dir="$2" entry relative_path
    if [[ -e "$target_dir" || -L "$target_dir" ]] && \
        { [[ ! -d "$target_dir" ]] || [[ -L "$target_dir" ]]; }; then
        backup_existing "$target_dir"
    fi
    mkdir -p "$target_dir"
    while IFS= read -r -d '' entry; do
        relative_path="${entry#"$source_dir"/}"
        backup_and_link "$entry" "$target_dir/$relative_path"
    done < <(find "$source_dir" -mindepth 1 -type f -print0)
}

say "Refreshing APT package indexes"
ensure_backports
ensure_firmware_archive
ensure_tailscale_archive
sudo apt-get update

say "Installing Debian archive packages"
mapfile -t APT_PACKAGES < <(awk 'NF && $1 !~ /^#/ { print $1 }' "$PACKAGES_FILE")
sudo apt-get install -y "${APT_PACKAGES[@]}"

say "Installing the Hyprland desktop from official Backports"
sudo apt-get install -y -t trixie-backports \
    hyprland hyprpaper hypridle hyprlock xdg-desktop-portal-hyprland

install_release_assets
install_tmux_plugins

if ! command -v codex >/dev/null; then
    say "Installing the Codex CLI from npm"
    sudo npm install --global @openai/codex
fi

say "Linking application configuration"
for app in btop dunst fcitx5 fish hypr kitty micro nvim waybar wlogout wofi yazi; do
    link_tree "$PROFILE_DIR/.config/$app" "$HOME/.config/$app"
done
backup_and_link \
    "$PROFILE_DIR/.config/Code/User/settings.json" \
    "$HOME/.config/Code/User/settings.json"
backup_and_link "$PROFILE_DIR/.tmux.conf" "$HOME/.tmux.conf"
backup_and_link "$PROFILE_DIR/.local/bin/battery-control.sh" "$HOME/.local/bin/battery-control.sh"

printf '\nInstallation finished. Log out, choose Hyprland in your display manager, then log in again.\n'
printf 'Configuration diagnostics after login: hyprctl configerrors\n'
if [[ -n "$BACKUP_ROOT" ]]; then
    printf 'Previous config files are backed up under: %s\n' "$BACKUP_ROOT"
fi

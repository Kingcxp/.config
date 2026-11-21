#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$SCRIPT_DIR/config"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/myconfig-debian"
BACKUP_ROOT=""

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 2; }

backup_existing() {
    local target="$1" backup
    [[ "$target" == "$HOME/"* ]] || die "Backup target is outside HOME: $target"
    if [[ -z "$BACKUP_ROOT" ]]; then
        BACKUP_ROOT="$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)-$$"
        mkdir -p "$BACKUP_ROOT"
        chmod 0700 "$BACKUP_ROOT"
    fi
    backup="$BACKUP_ROOT/${target#"$HOME"/}"
    # A parent may already have been backed up earlier in this installation.
    while [[ -e "$backup" || -L "$backup" ]]; do backup="$backup.previous"; done
    mkdir -p "$(dirname -- "$backup")"
    mv -- "$target" "$backup"
    printf 'Backed up %s to %s\n' "$target" "$backup"
}

ensure_directory() {
    local target="$1" parent
    [[ "$target" != "$HOME" ]] || return 0
    [[ "$target" == "$HOME/"* ]] || die "Config directory is outside HOME: $target"
    parent="$(dirname -- "$target")"
    ensure_directory "$parent"
    # Never follow an old dotfile directory symlink and edit the source repository.
    if [[ -L "$target" || ( -e "$target" && ! -d "$target" ) ]]; then backup_existing "$target"; fi
    mkdir -p "$target"
}

backup_and_link() {
    local source="$1" target="$2"
    [[ -f "$source" ]] || die "Missing profile file: $source"
    ensure_directory "$(dirname -- "$target")"
    if [[ -L "$target" ]] && [[ "$(readlink -f -- "$target" 2>/dev/null || true)" == "$(readlink -f -- "$source")" ]]; then return; fi
    if [[ -e "$target" || -L "$target" ]]; then backup_existing "$target"; fi
    ln -s -- "$source" "$target"
}

link_tree() {
    local source="$1" target="$2" entry
    ensure_directory "$target"
    while IFS= read -r -d '' entry; do
        backup_and_link "$entry" "$target/${entry#"$source"/}"
    done < <(find "$source" -mindepth 1 -type f -print0)
}

install_tmux_plugins() {
    local root="$HOME/.config/tmux/plugins" target spec url
    ensure_directory "$root"
    for spec in catppuccin/tmux tmux-plugins/tmux-cpu tmux-plugins/tmux-battery; do
        target="$root/$spec"
        ensure_directory "$(dirname -- "$target")"
        # Keep an existing genuine checkout; back up incomplete paths before retrying.
        if [[ -d "$target/.git" ]]; then continue; fi
        if [[ -e "$target" || -L "$target" ]]; then backup_existing "$target"; fi
        url="https://github.com/$spec.git"
        git clone --depth 1 "$url" "$target"
    done
}

install_session_path() {
    local prefix=/home/linuxbrew/.linuxbrew file="$STATE_DIR/session-path.conf"
    mkdir -p "$STATE_DIR"
    if [[ -r "$STATE_DIR/brew-prefix" ]]; then IFS= read -r prefix <"$STATE_DIR/brew-prefix"; fi
    [[ "$prefix" == /* && "$prefix" != *[[:space:]]* ]] || die "Invalid Homebrew prefix: $prefix"
    # Expansion happens in systemd's environment.d parser, not in this shell.
    # shellcheck disable=SC2016
    printf 'PATH=%s/opt/node@22/bin:%s/bin:%s/sbin:${HOME}/.local/bin:${PATH}\n' "$prefix" "$prefix" "$prefix" >"$file"
    # shellcheck disable=SC2016
    printf 'XDG_DATA_DIRS=%s/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\n' "$prefix" >>"$file"
    printf '%s\n' 'LANG=zh_CN.UTF-8' 'LANGUAGE=zh_CN:en_US' >>"$file"
    backup_and_link "$file" "$HOME/.config/environment.d/20-myconfig-path.conf"
}

main() {
    local configs_only=false status=0 app
    case "${1:-}" in
        --dry-run)
            [[ "$#" == 1 ]] || die 'Use one option at a time'
            bash "$SCRIPT_DIR/install-software.sh" --dry-run
            printf '\nConfig links: %s -> %s (with dated backups)\n' "$PROFILE_DIR" "$HOME"
            return ;;
        --manual) bash "$SCRIPT_DIR/install-software.sh" "$@"; return ;;
        --configs-only) [[ "$#" == 1 ]] || die 'Use one option at a time'; configs_only=true ;;
        --help|-h)
            printf 'Usage: bash install.sh [--dry-run | --manual | --configs-only | --help]\nDefault: install the complete APT/Homebrew software list, then deploy desktop configuration.\n--configs-only: deploy config and tmux plugins without APT/Homebrew operations.\n'
            return ;;
        '') [[ "$#" == 0 ]] || die 'Unexpected empty argument' ;;
        *) die "Unknown option: $1" ;;
    esac
    [[ "$EUID" -ne 0 ]] || die 'Run as your normal user, without sudo.'
    [[ "$(uname -s)" == Linux ]] || die 'Run this installer on Debian, not Windows or macOS.'
    [[ -d "$PROFILE_DIR/.config" ]] || die "Missing profile: $PROFILE_DIR"
    # Standard XDG paths are deliberately used by the original profile and helpers.
    [[ "${XDG_CONFIG_HOME:-$HOME/.config}" == "$HOME/.config" ]] || die "This profile requires XDG_CONFIG_HOME=$HOME/.config."
    if [[ "$configs_only" == false ]]; then
        bash "$SCRIPT_DIR/install-software.sh" || status=$?
        (( status < 2 )) || return "$status"
    fi
    say 'Backing up and linking Debian application configuration'
    for app in btop dunst fcitx5 fish hypr kitty micro nvim waybar wlogout wofi yazi fontconfig xdg-desktop-portal gtk-3.0 gtk-4.0; do
        link_tree "$PROFILE_DIR/.config/$app" "$HOME/.config/$app"
    done
    link_tree "$PROFILE_DIR/.local/bin" "$HOME/.local/bin"
    link_tree "$PROFILE_DIR/.local/share" "$HOME/.local/share"
    backup_and_link "$PROFILE_DIR/.config/Code/User/settings.json" "$HOME/.config/Code/User/settings.json"
    backup_and_link "$PROFILE_DIR/.config/Code/argv.json" "$HOME/.config/Code/argv.json"
    # Both names resolve to the same config, so the XDG entry cannot shadow ~/.tmux.conf.
    backup_and_link "$PROFILE_DIR/.tmux.conf" "$HOME/.tmux.conf"
    backup_and_link "$PROFILE_DIR/.tmux.conf" "$HOME/.config/tmux/tmux.conf"
    install_session_path
    install_tmux_plugins
    if command -v im-config >/dev/null; then im-config -n fcitx5; fi
    if command -v xdg-user-dirs-update >/dev/null; then xdg-user-dirs-update; fi
    if command -v fc-cache >/dev/null; then fc-cache -f; fi
    printf '\nConfiguration deployed. Log out and choose Hyprland, or start Hyprland from a TTY.\n'
    printf 'After login: hyprctl configerrors; hyprctl monitors; fcitx5-diagnose\n'
    if [[ -n "$BACKUP_ROOT" ]]; then printf 'Config backups: %s\n' "$BACKUP_ROOT"; fi
    if (( status )); then printf 'Some software installations failed; check %s/failed-packages.txt.\n' "$STATE_DIR" >&2; fi
    return "$status"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi

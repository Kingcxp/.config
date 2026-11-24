#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$SCRIPT_DIR/config"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/myconfig-debian"
BACKUP_ROOT=""
# Linted separately; no actions are executed on import.
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/desktop-migration.sh"
# These helpers define functions only; the complete desktop refresh is invoked
# explicitly by install.sh --refresh.
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/configure-system.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/install-appearance.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/configure-grub.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/configure-existing-desktop.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/configure-editor.sh"

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
    printf 'XDG_DATA_DIRS=%s/share:/usr/local/share:/usr/share:${XDG_DATA_DIRS}\n' "$prefix" >>"$file"
    printf '%s\n' 'LANG=zh_CN.UTF-8' 'LANGUAGE=zh_CN:en_US' >>"$file"
    backup_and_link "$file" "$HOME/.config/environment.d/20-myconfig-path.conf"
}

install_tray_icon_theme() {
    local theme_dir="$STATE_DIR/tray-icons/Myconfig-Papirus-Dark"
    python3 "$SCRIPT_DIR/lib/build-tray-theme.py" /usr/share/icons/Papirus-Dark/22x22/panel "$theme_dir" || return
    link_tree "$theme_dir" "$HOME/.local/share/icons/Myconfig-Papirus-Dark"
}

deploy_user_configuration() {
    local app
    say 'Backing up and linking Debian application configuration'
    for app in btop dunst fcitx5 fish hypr kitty micro nvim waybar wlogout wofi yazi fontconfig xdg-desktop-portal gtk-3.0 gtk-4.0 Kvantum qt5ct qt6ct systemd; do
        link_tree "$PROFILE_DIR/.config/$app" "$HOME/.config/$app"
    done
    if command -v docker >/dev/null 2>&1 && [[ -f "$HOME/.config/systemd/user/docker.service" ]]; then
        link_tree "$PROFILE_DIR/.config/environment.d" "$HOME/.config/environment.d"
    fi
    link_tree "$PROFILE_DIR/.local/bin" "$HOME/.local/bin"
    link_tree "$PROFILE_DIR/.local/share" "$HOME/.local/share"
    install_tray_icon_theme
    backup_and_link "$PROFILE_DIR/.config/Code/User/settings.json" "$HOME/.config/Code/User/settings.json"
    backup_and_link "$PROFILE_DIR/.config/Code/argv.json" "$HOME/.config/Code/argv.json"
    backup_and_link "$PROFILE_DIR/.tmux.conf" "$HOME/.tmux.conf"
    backup_and_link "$PROFILE_DIR/.tmux.conf" "$HOME/.config/tmux/tmux.conf"
    backup_and_link "$PROFILE_DIR/.xinputrc" "$HOME/.xinputrc"
    backup_and_link "$PROFILE_DIR/.gtkrc-2.0" "$HOME/.gtkrc-2.0"
    install_session_path
}

finish_desktop_install() {
    local configs_only="$1" replace_kde="$2" software_status="$3"
    [[ "$configs_only" == false ]] || return 0
    desktop_install_login || return 2
    if [[ "$replace_kde" == true && "$software_status" == 0 ]]; then
        desktop_remove_kde || return 2
    elif [[ "$replace_kde" == true ]]; then
        printf 'Software installation has failures; KDE is retained. Fix the failures and rerun.\n' >&2
    fi
}

main() {
    local configs_only=false status=0 dry_run=false replace_kde=true refresh=false editor_only=false
    local software_args=()
    while (( $# )); do
        case "$1" in
            --refresh) refresh=true; shift ;;
            --editor) editor_only=true; shift ;;
            --mirror)
                if (( $# < 2 )) || [[ "$2" != official && "$2" != nju ]]; then die '--mirror requires official or nju'; fi
                software_args+=(--mirror "$2"); shift 2 ;;
            --keep-kde) replace_kde=false; shift ;;
            --configs-only) configs_only=true; replace_kde=false; shift ;;
            --dry-run) dry_run=true; shift ;;
            --manual) bash "$SCRIPT_DIR/install-software.sh" --manual; return ;;
            --help|-h)
                printf 'Usage: bash install.sh [--mirror official|nju] [--keep-kde] [--dry-run | --configs-only]\n       bash install.sh --refresh [--dry-run]\n       bash install.sh --editor [--dry-run]\nDefault: install software, deploy/check Hyprland, configure SDDM, then remove KDE.\nLog out of KDE first and run from a TTY (Ctrl+Alt+F3). --keep-kde skips removal.\n--configs-only deploys user config/tmux plugins, with no APT or system/login changes.\n--refresh reapplies the complete desktop/user configuration and installs missing desktop/JSON-LSP prerequisites; it does not reinstall the full software manifest or remove KDE.\n--editor installs missing JSON/HTML/CSS language servers using existing Homebrew and deploys only Neovim configuration.\nAdd --dry-run to preview changes without modifying the system.\n'
                return ;;
            *) die "Unknown option: $1" ;;
        esac
    done
    if [[ "$editor_only" == true ]]; then
        [[ "$refresh" == false && "$configs_only" == false && "$replace_kde" == true && ${#software_args[@]} == 0 ]] \
            || die '--editor cannot be combined with --refresh, --mirror, --keep-kde, or --configs-only.'
        if [[ "$dry_run" == true ]]; then
            printf 'Editor plan: restore Homebrew/Node PATH, install missing vscode-langservers-extracted commands, and back up/link Neovim configuration. Mason installs are manual. No desktop, APT, GRUB, or KDE changes.\n'
            return 0
        fi
        [[ -d "$PROFILE_DIR/.config" ]] || die "Missing profile: $PROFILE_DIR"
        configure_editor_only
        return $?
    fi
    if [[ "$refresh" == true ]]; then
        [[ "$configs_only" == false && "$replace_kde" == true && ${#software_args[@]} == 0 ]] \
            || die '--refresh cannot be combined with --mirror, --keep-kde, or --configs-only.'
        if [[ "$dry_run" == true ]]; then
            printf 'Desktop refresh plan: install missing desktop prerequisites and JSON/HTML/CSS server commands; apply Catppuccin/SDDM/GRUB settings; deploy all user configuration; validate Hyprland and Waybar fonts; refresh Waybar, Fcitx, network and USB tray apps in an active Hyprland session. No full software-manifest install or KDE removal.\n'
            return 0
        fi
        [[ -d "$PROFILE_DIR/.config" ]] || die "Missing profile: $PROFILE_DIR"
        configure_existing_desktop
        return $?
    fi
    [[ "$replace_kde" == false ]] || software_args+=(--desktop-migration)
    if [[ "$dry_run" == true ]]; then
        if [[ "$configs_only" == false ]]; then bash "$SCRIPT_DIR/install-software.sh" "${software_args[@]}" --dry-run; fi
        printf '\nConfig links: %s -> %s (with dated backups)\n' "$PROFILE_DIR" "$HOME"
        if [[ "$replace_kde" == true ]]; then
            printf 'Desktop: require KDE logged out; check dependencies/config, keep SDDM/Dolphin/Ark, simulate explicit KDE removal, then purge; no autoremove.\n'
        fi
        return
    fi
    [[ "$EUID" -ne 0 ]] || die 'Run as your normal user, without sudo.'
    [[ "$(uname -s)" == Linux ]] || die 'Run this installer on Debian, not Windows or macOS.'
    [[ -d "$PROFILE_DIR/.config" ]] || die "Missing profile: $PROFILE_DIR"
    # Standard XDG paths are deliberately used by the original profile and helpers.
    [[ "${XDG_CONFIG_HOME:-$HOME/.config}" == "$HOME/.config" ]] || die "This profile requires XDG_CONFIG_HOME=$HOME/.config."
    if [[ "$replace_kde" == true ]]; then desktop_check_session; fi
    if [[ "$configs_only" == false ]]; then desktop_check_manager; fi
    if [[ "$configs_only" == false ]]; then
        bash "$SCRIPT_DIR/install-software.sh" "${software_args[@]}" || status=$?
        (( status < 2 )) || return "$status"
    fi
    deploy_user_configuration
    if ! bash "$SCRIPT_DIR/lib/user-appearance.sh" "$STATE_DIR"; then
        printf 'Failed to apply desktop font/theme settings; KDE will be retained.\n' >&2
        status=1
    fi
    install_tmux_plugins
    if command -v xdg-user-dirs-update >/dev/null; then xdg-user-dirs-update; fi
    if command -v fc-cache >/dev/null; then fc-cache -f; fi
    finish_desktop_install "$configs_only" "$replace_kde" "$status"
    if [[ "$configs_only" == true ]]; then
        printf '\nUser configuration deployed; system packages and login setup were not changed.\n'
    else
        printf '\nConfiguration deployed. Reboot when ready; choose Hyprland (myconfig) in SDDM.\n'
    fi
    printf 'After login: bash %q/check-desktop.sh; fcitx5-diagnose\n' "$SCRIPT_DIR"
    if [[ -n "$BACKUP_ROOT" ]]; then printf 'Config backups: %s\n' "$BACKUP_ROOT"; fi
    if (( status )); then printf 'Some software installations failed; check %s/failed-packages.txt.\n' "$STATE_DIR" >&2; fi
    return "$status"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi

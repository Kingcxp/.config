#!/usr/bin/env bash
# Run as the desktop user, with a session bus (also works from a TTY via dbus-run-session).

apply_user_appearance() {
    local state_dir="$1" backup schema=org.gnome.desktop.interface key value current changed=false
    local -a changes=()
    if ! command -v gsettings >/dev/null || ! command -v dconf >/dev/null; then
        printf 'gsettings/dconf are required to replace old KDE/GTK appearance settings.\n' >&2
        return 1
    fi
    gsettings list-schemas | grep -Fxq "$schema" || return 1
    while IFS='|' read -r key value; do
        current="$(gsettings get "$schema" "$key")" || return 1
        if [[ "$current" != "$value" ]]; then changes+=("$key|$value"); fi
    done <<'SETTINGS'
gtk-theme|'catppuccin-macchiato-lavender-standard'
icon-theme|'Papirus-Dark'
font-name|'JetBrainsMono Nerd Font 12'
monospace-font-name|'JetBrainsMono Nerd Font 13'
cursor-theme|'catppuccin-macchiato-lavender-cursors'
cursor-size|32
text-scaling-factor|1.0
color-scheme|'prefer-dark'
SETTINGS
    if (( ${#changes[@]} )); then
        backup="$state_dir/appearance-backups/$(date +%Y%m%d-%H%M%S)-$$"
        mkdir -p "$backup" || return 1
        dconf dump /org/gnome/desktop/interface/ >"$backup/gnome-interface.dconf" || return 1
        for current in "${changes[@]}"; do
            IFS='|' read -r key value <<<"$current"
            gsettings set "$schema" "$key" "$value" || return 1
            changed=true
        done
        printf 'Applied desktop font/theme settings; previous dconf settings: %s\n' "$backup"
    fi
    [[ "$changed" == true ]] || printf 'Desktop font/theme settings already match myconfig.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -Eeuo pipefail
    (( $# == 1 )) || { printf 'Usage: user-appearance.sh STATE_DIR\n' >&2; exit 2; }
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        exec dbus-run-session -- bash "$0" "$1"
    fi
    apply_user_appearance "$1"
fi

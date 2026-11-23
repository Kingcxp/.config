#!/usr/bin/env bash
# Run as the desktop user, with a session bus (also works from a TTY via dbus-run-session).

myconfig_gsettings() {
    # Homebrew's GLib may appear first in PATH and use a different settings
    # backend. The APT desktop must write persistent settings through Debian.
    GSETTINGS_BACKEND=dconf GSETTINGS_SCHEMA_DIR=/usr/share/glib-2.0/schemas /usr/bin/gsettings "$@"
}

apply_user_appearance() {
    local state_dir="$1" scope="${2:-all}" backup schema=org.gnome.desktop.interface key value current changed=false
    local -a changes=()
    if [[ ! -x /usr/bin/gsettings || ! -x /usr/bin/dconf ]]; then
        printf 'Debian libglib2.0-bin and dconf-cli are required for desktop settings.\n' >&2
        return 1
    fi
    # Consume the whole stream: grep -q can SIGPIPE a large schema list under pipefail.
    myconfig_gsettings list-schemas | grep -Fx "$schema" >/dev/null || return 1
    while IFS='|' read -r key value; do
        if [[ "$scope" == icons && "$key" != icon-theme ]]; then continue; fi
        current="$(myconfig_gsettings get "$schema" "$key")" || return 1
        if [[ "$current" != "$value" ]]; then changes+=("$key|$value"); fi
    done <<'SETTINGS'
gtk-theme|'catppuccin-macchiato-lavender-standard'
icon-theme|'Myconfig-Papirus-Dark'
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
        /usr/bin/dconf dump /org/gnome/desktop/interface/ >"$backup/gnome-interface.dconf" || return 1
        for current in "${changes[@]}"; do
            IFS='|' read -r key value <<<"$current"
            myconfig_gsettings set "$schema" "$key" "$value" || return 1
            current="$(myconfig_gsettings get "$schema" "$key")" || return 1
            if [[ "$current" != "$value" ]]; then
                printf 'Desktop setting did not persist: %s (expected %s, got %s)\n' "$key" "$value" "$current" >&2
                return 1
            fi
            changed=true
        done
        printf 'Applied desktop appearance settings; previous dconf settings: %s\n' "$backup"
    fi
    [[ "$changed" == true ]] || printf 'Requested desktop appearance settings already match myconfig.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -Eeuo pipefail
    if (( $# < 1 || $# > 2 )) || [[ "${2:-all}" != all && "${2:-all}" != icons ]]; then
        printf 'Usage: user-appearance.sh STATE_DIR [all|icons]\n' >&2
        exit 2
    fi
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        exec dbus-run-session -- bash "$0" "$@"
    fi
    apply_user_appearance "$@"
fi

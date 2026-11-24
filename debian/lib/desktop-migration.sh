#!/usr/bin/env bash
# Loaded by the installers; no action is taken just by sourcing this file.
# Redirected plans/config drafts intentionally belong to the invoking user.
# shellcheck disable=SC2024
DESKTOP_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

desktop_installed() { dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null | grep -qx installed; }

desktop_check_session() {
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        printf 'This desktop migration must run from a local TTY, not over SSH.\n' >&2
        return 2
    fi
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]] || pgrep -u "$(id -u)" -x 'plasmashell|kwin_wayland|kwin_x11' >/dev/null; then
        printf 'Save your work, log out of KDE, then use Ctrl+Alt+F3 and run the installer there.\nUse --keep-kde to install without removing the running desktop.\n' >&2
        return 2
    fi
}

desktop_check_manager() {
    local manager
    if [[ -r /etc/X11/default-display-manager ]]; then
        IFS= read -r manager </etc/X11/default-display-manager
        if [[ -n "$manager" && "$manager" != /usr/bin/sddm ]]; then
            printf 'Detected another display manager: %s. This KDE migration requires SDDM.\n' "$manager" >&2
            return 2
        fi
    fi
}

desktop_check_plan() {
    local plan="$1" package allowed found
    shift
    while IFS= read -r package; do
        found=false
        for allowed in "$@"; do [[ "$package" != "$allowed" ]] || found=true; done
        if [[ "$found" == false ]]; then
            printf 'Refusing unexpected package removal: %s. Inspect %s\n' "$package" "$plan" >&2
            return 2
        fi
    done < <(awk '/^(Remv|Purg) / { sub(/:.*/, "", $2); print $2 }' "$plan")
}

desktop_power_transition() {
    desktop_installed power-profiles-daemon || return 0
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/myconfig-debian" plan
    mkdir -p "$state_dir"
    plan="$state_dir/power-transition-plan.txt"
    # The plan deliberately belongs to the invoking user, not root.
    # shellcheck disable=SC2024
    sudo env LC_ALL=C apt-get --simulate install -t trixie-backports tlp tlp-pd >"$plan" || return 2
    desktop_check_plan "$plan" power-profiles-daemon || return 2
    printf 'Replacing power-profiles-daemon with TLP / tlp-pd (desktop migration).\n'
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -t trixie-backports tlp tlp-pd \
        -o APT::Get::AutomaticRemove=false
}

desktop_system_file() {
    local source="$1" target="$2" mode="${3:-0644}"
    local backup actual_mode
    backup="/var/backups/myconfig-debian/desktop/$(date +%Y%m%d)-$$"
    if ! sudo test -L "$target" && sudo cmp -s -- "$source" "$target" 2>/dev/null; then
        actual_mode="$(sudo stat -c '%a' -- "$target" 2>/dev/null || true)"
        if [[ "$actual_mode" == "${mode#0}" ]]; then return 0; fi
        sudo chmod "$mode" "$target"
        return $?
    fi
    sudo install -d -m 0700 "$backup" || return 2
    if [[ -e "$target" ]]; then sudo cp --parents -- "$target" "$backup/" || return 2; fi
    sudo install -D -m "$mode" "$source" "$target"
}

desktop_configure_greeter() {
    local work
    if ! sudo test -s /usr/share/sddm/themes/catppuccin-macchiato-lavender/Main.qml; then
        printf 'Catppuccin SDDM theme is missing; the existing greeter configuration was not changed.\n' >&2
        return 2
    fi
    work="$(mktemp -d)"
    # /etc/sddm.conf has higher priority than snippets; preserve its other options.
    sudo python3 "$DESKTOP_DIR/lib/configure-sddm.py" /etc/sddm.conf >"$work/sddm.conf" || { rm -rf -- "$work"; return 2; }
    desktop_system_file "$work/sddm.conf" /etc/sddm.conf || { rm -rf -- "$work"; return 2; }
    rm -rf -- "$work"
}

desktop_install_login() {
    local work
    work="$(mktemp -d)"
    desktop_system_file "$DESKTOP_DIR/session/myconfig-hyprland" /usr/local/bin/myconfig-hyprland 0755 || { rm -rf -- "$work"; return 2; }
    desktop_system_file "$DESKTOP_DIR/session/myconfig-hyprland.desktop" /usr/share/wayland-sessions/myconfig-hyprland.desktop || { rm -rf -- "$work"; return 2; }
    desktop_configure_greeter || { rm -rf -- "$work"; return 2; }
    sudo python3 "$DESKTOP_DIR/lib/configure-sddm.py" /var/lib/sddm/state.conf --user "$(id -un)" >"$work/state.conf" || { rm -rf -- "$work"; return 2; }
    desktop_system_file "$work/state.conf" /var/lib/sddm/state.conf 0600 || { rm -rf -- "$work"; return 2; }
    sudo chown sddm:sddm /var/lib/sddm/state.conf || { rm -rf -- "$work"; return 2; }
    printf '/usr/bin/sddm\n' >"$work/display-manager"
    desktop_system_file "$work/display-manager" /etc/X11/default-display-manager || { rm -rf -- "$work"; return 2; }
    rm -rf -- "$work"
    # Enable the next boot; do not terminate a session or start a greeter mid-install.
    sudo systemctl enable sddm.service || return 2
    sudo systemctl enable NetworkManager.service bluetooth.service || return 2
    sudo systemctl set-default graphical.target || return 2
}

desktop_remove_kde() {
    desktop_check_session || return 2
    bash "$DESKTOP_DIR/check-desktop.sh" --preflight || return 2
    local package state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/myconfig-debian" plan
    local allowed=() installed=()
    mapfile -t allowed < <(awk 'NF && $1 !~ /^#/ { sub(/\r$/, "", $1); print $1 }' "$DESKTOP_DIR/kde-desktop-packages.txt")
    for package in "${allowed[@]}"; do
        if desktop_installed "$package"; then installed+=("$package"); fi
    done
    (( ${#installed[@]} )) || { printf 'No KDE desktop packages remain.\n'; return; }
    mkdir -p "$state_dir"
    plan="$state_dir/kde-removal-plan.txt"
    dpkg-query -W -f='${binary:Package}\t${Version}\n' >"$state_dir/packages-before-kde-removal.txt"
    sudo apt-mark manual sddm sddm-theme-debian-maui hyprland kitty dolphin ark \
        network-manager dbus-user-session pipewire-audio fcitx5 mate-polkit || return 2
    # The plan deliberately belongs to the invoking user, not root.
    # shellcheck disable=SC2024
    sudo env LC_ALL=C apt-get --simulate purge "${installed[@]}" -o APT::Get::AutomaticRemove=false >"$plan" || return 2
    desktop_check_plan "$plan" "${allowed[@]}" || return 2
    printf 'Removing KDE desktop packages; plan: %s\n' "$plan"
    sudo env DEBIAN_FRONTEND=noninteractive apt-get purge -y "${installed[@]}" -o APT::Get::AutomaticRemove=false || return 2
    bash "$DESKTOP_DIR/check-desktop.sh" --preflight
}

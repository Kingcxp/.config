#!/usr/bin/env bash
# Repair the installed profile without upgrading all software or removing desktop packages.
# shellcheck disable=SC1091
set -Eeuo pipefail
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install.sh
source "$SCRIPT_DIR/install.sh"
# shellcheck source=lib/configure-system.sh
source "$SCRIPT_DIR/lib/configure-system.sh"
# shellcheck source=lib/install-appearance.sh
source "$SCRIPT_DIR/lib/install-appearance.sh"
# shellcheck source=lib/configure-grub.sh
source "$SCRIPT_DIR/lib/configure-grub.sh"
WORK_DIR=""
FAILURES=()
trap 'if [[ -n "$WORK_DIR" ]]; then rm -rf -- "$WORK_DIR"; fi' EXIT

repair_main() {
    local panel_login=false
    case "${1:-}" in
        --dry-run)
            printf 'Repair Catppuccin SDDM, Waybar Lua workspace clicks, Fish/Waybar fonts and themes, inherited GTK input variables, missing Hyprland GUI utilities, dconf appearance, and GRUB.\n'
            printf 'Arrange the top bar: title/hardware/network left; workspaces center; tray/audio/brightness/clock/battery/power right.\n'
            printf 'Install missing desktop prerequisites only; no Homebrew update, full software installation, KDE removal, display-manager restart, or automatic reboot.\n'
            return ;;
        --help|-h) printf 'Usage: bash repair-desktop.sh [--dry-run | --panel-login]\n--panel-login repairs only Waybar and the SDDM theme, without changing GRUB or the desktop session.\nRun as the same ordinary user who installed myconfig.\n'; return ;;
        --panel-login) panel_login=true ;;
        '') ;;
        *) die 'Usage: bash repair-desktop.sh [--dry-run | --panel-login]' ;;
    esac
    (( $# <= 1 )) || die 'Too many arguments'
    [[ "$EUID" -ne 0 ]] || die 'Run as your normal user, without sudo.'
    [[ "$(uname -s)" == Linux ]] || die 'Run this repair on the installed Debian system.'
    [[ "${XDG_CONFIG_HOME:-$HOME/.config}" == "$HOME/.config" ]] || die 'This profile requires the standard ~/.config directory.'
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == debian && "${VERSION_CODENAME:-}" == trixie ]] || die 'Requires Debian 13 Trixie.'
    sudo -v
    WORK_DIR="$(mktemp -d)"
    mkdir -p "$STATE_DIR"
    exec > >(tee -a "$STATE_DIR/repair-desktop.log") 2>&1
    local package need_guiutils=false
    local -a missing=()
    if [[ "$panel_login" == true ]]; then
        for package in sddm curl ca-certificates unzip xz-utils python3 fontconfig \
            qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts \
            qml6-module-qtquick-window qml6-module-qtquick-templates qml6-module-qtqml-models \
            qml6-module-qtqml-workerscript libqt6svg6 qt6-svg-plugins; do
            if ! desktop_installed "$package"; then missing+=("$package"); fi
        done
        if (( ${#missing[@]} )); then
            sudo apt-get update -o APT::Update::Error-Mode=any
            sudo apt-get install --no-remove -y "${missing[@]}"
        fi
        configure_catppuccin_sddm "$WORK_DIR" "$SCRIPT_DIR" || die 'Install the verified Catppuccin SDDM theme'
        desktop_configure_greeter || die 'Apply the SDDM theme and disable the virtual keyboard'
        backup_and_link "$PROFILE_DIR/.config/wlogout/layout" "$HOME/.config/wlogout/layout"
        backup_and_link "$PROFILE_DIR/.config/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
        bash "$SCRIPT_DIR/repair-waybar.sh"
        printf '\nWaybar repaired now; save your work and reboot when ready to load the new SDDM theme.\n'
        printf 'The updated logout/wake commands load on the next session; the display manager was not restarted.\n'
        return
    fi
    for package in curl ca-certificates unzip xz-utils python3 fish fontconfig fonts-noto-cjk fonts-font-awesome papirus-icon-theme \
        dconf-cli gsettings-desktop-schemas libglib2.0-bin dbus-user-session qt5ct qt6ct \
        qt5-style-kvantum qt6-style-kvantum grub-common grub2-common \
        qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts \
        qml6-module-qtquick-window qml6-module-qtquick-templates qml6-module-qtqml-models \
        qml6-module-qtqml-workerscript libqt6svg6 qt6-svg-plugins; do
        if ! desktop_installed "$package"; then missing+=("$package"); fi
    done
    if ! desktop_installed hyprland-guiutils; then need_guiutils=true; fi
    if (( ${#missing[@]} )) || [[ "$need_guiutils" == true ]]; then
        sudo apt-get update -o APT::Update::Error-Mode=any
    fi
    if (( ${#missing[@]} )); then
        sudo apt-get install --no-remove -y "${missing[@]}"
    fi
    if [[ "$need_guiutils" == true ]]; then
        sudo apt-get install --no-remove -y -t trixie-backports hyprland-guiutils
    fi
    configure_catppuccin_appearance "$WORK_DIR" "$SCRIPT_DIR"
    refresh_grub_menu
    if [[ -d /sys/firmware/efi ]] && command -v efibootmgr >/dev/null; then
        printf '\nCurrent UEFI boot entries (read-only; saved for diagnosing a different active bootloader):\n'
        sudo efibootmgr -v || true
    fi
    desktop_configure_greeter || setup_failure 'Apply the Catppuccin SDDM theme and disable the virtual keyboard'
    desktop_system_file "$SCRIPT_DIR/session/myconfig-hyprland" /usr/local/bin/myconfig-hyprland 0755 \
        || setup_failure 'Update the Hyprland session wrapper to clear inherited GTK_IM_MODULE'
    deploy_user_configuration
    bash "$SCRIPT_DIR/lib/user-appearance.sh" "$STATE_DIR" || setup_failure 'Apply the desktop font/theme settings'
    fc-cache -f || setup_failure 'Refresh the user font cache'
    fc-match 'JetBrainsMono Nerd Font'
    fc-match 'Noto Sans CJK SC'
    python3 "$SCRIPT_DIR/lib/check-waybar-fonts.py" "$HOME/.config/waybar/config.jsonc" \
        || setup_failure 'Verify the actual Waybar fonts contain every configured icon'
    if command -v Hyprland >/dev/null; then
        timeout 30s Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua" \
            || setup_failure 'Validate the repaired Hyprland configuration'
    else
        setup_failure 'Hyprland is not installed; the full desktop installation is incomplete'
    fi
    if (( ${#FAILURES[@]} )); then
        printf '%s\n' "${FAILURES[@]}" >"$STATE_DIR/repair-failures.txt"
        printf '\nRepair incomplete. See %s/repair-desktop.log and repair-failures.txt.\n' "$STATE_DIR" >&2
        return 1
    fi
    rm -f -- "$STATE_DIR/repair-failures.txt"
    printf '\nRepair applied. Save work and log out/in to reload the desktop and SDDM; reboot to check GRUB.\n'
    printf 'No session was restarted. Backups are under %s and /var/backups/myconfig-debian/.\n' "$STATE_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then repair_main "$@"; fi

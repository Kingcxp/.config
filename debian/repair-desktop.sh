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
    case "${1:-}" in
        --dry-run)
            printf 'Repair SDDM InputMethod, verify/install desktop fonts and pinned themes, redeploy configuration, back up/apply dconf fonts, and regenerate/verify GRUB.\n'
            printf 'Restore original top-bar arrangement: title/hardware left; workspaces center; tray/audio/brightness/network/clock/battery/power right.\n'
            printf 'Install missing desktop prerequisites only; no Homebrew update, full software installation, KDE removal, display-manager restart, or automatic reboot.\n'
            return ;;
        --help|-h) printf 'Usage: bash repair-desktop.sh [--dry-run]\nRun as the same ordinary user who installed myconfig. Save work and log out/in after completion.\n'; return ;;
        '') ;;
        *) die 'Usage: bash repair-desktop.sh [--dry-run]' ;;
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
    local package
    local -a missing=()
    for package in curl ca-certificates unzip xz-utils fontconfig fonts-noto-cjk fonts-font-awesome \
        dconf-cli gsettings-desktop-schemas libglib2.0-bin dbus-user-session qt5ct qt6ct \
        qt5-style-kvantum qt6-style-kvantum grub-common grub2-common; do
        if ! desktop_installed "$package"; then missing+=("$package"); fi
    done
    if (( ${#missing[@]} )); then
        sudo apt-get update -o APT::Update::Error-Mode=any
        sudo apt-get install --no-remove -y "${missing[@]}"
    fi
    configure_catppuccin_appearance "$WORK_DIR" "$SCRIPT_DIR"
    refresh_grub_menu
    if [[ -d /sys/firmware/efi ]] && command -v efibootmgr >/dev/null; then
        printf '\nCurrent UEFI boot entries (read-only; saved for diagnosing a different active bootloader):\n'
        sudo efibootmgr -v || true
    fi
    desktop_configure_greeter || setup_failure 'Disable the SDDM virtual keyboard'
    deploy_user_configuration
    bash "$SCRIPT_DIR/lib/user-appearance.sh" "$STATE_DIR" || setup_failure 'Apply the desktop font/theme settings'
    fc-cache -f || setup_failure 'Refresh the user font cache'
    fc-match 'JetBrainsMono Nerd Font'
    fc-match 'Noto Sans CJK SC'
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

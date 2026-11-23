#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

check_main() {
    local preflight=false command unit failed=0 output
    case "${1:-}" in
        --preflight) preflight=true ;;
        --help|-h) printf 'Usage: bash check-desktop.sh [--preflight]\nPreflight checks dependencies/config without starting a desktop. Default also checks the running Hyprland session.\n'; return ;;
        '') ;;
        *) printf 'Unknown check option\n' >&2; return 2 ;;
    esac
    (( $# <= 1 )) || return 2
    for command in Hyprland hyprctl hyprland-dialog waybar kitty wofi wlogout dunst hyprpaper hypridle hyprlock \
        fcitx5 fcitx5-configtool fcitx5-remote nm-applet blueman-applet wpctl brightnessctl grim slurp \
        dbus-update-activation-environment gnome-keyring-daemon; do
        if ! command -v "$command" >/dev/null; then printf 'MISSING: %s\n' "$command" >&2; failed=1; fi
    done
    for output in "$HOME/.config/hypr/hyprland.lua" "$HOME/.config/waybar/config.jsonc" \
        "$HOME/.config/fcitx5/profile" "$HOME/.config/fcitx5/conf/classicui.conf" \
        "$HOME/.config/Kvantum/kvantum.kvconfig" "$HOME/.config/qt5ct/qt5ct.conf" "$HOME/.config/qt6ct/qt6ct.conf" \
        "$HOME/.config/systemd/user/xdg-desktop-portal-gtk.service.d/10-fcitx.conf" \
        /usr/libexec/polkit-mate-authentication-agent-1 /etc/pam.d/hyprlock \
        /usr/bin/sddm /usr/share/sddm/themes/debian-maui/Main.qml /usr/local/bin/myconfig-hyprland \
        /usr/share/wayland-sessions/myconfig-hyprland.desktop \
        /usr/local/share/themes/catppuccin-macchiato-lavender-standard/gtk-3.0/gtk.css \
        /usr/local/share/themes/catppuccin-macchiato-lavender-standard/gtk-4.0/gtk.css \
        /usr/local/share/icons/catppuccin-macchiato-lavender-cursors/index.theme \
        /usr/share/Kvantum/catppuccin-macchiato-lavender/catppuccin-macchiato-lavender.kvconfig \
        /usr/local/share/fcitx5/themes/catppuccin-macchiato-lavender/theme.conf \
        /boot/grub/themes/catppuccin-macchiato-grub-theme/theme.txt \
        /boot/grub/themes/catppuccin-macchiato-grub-theme/font.pf2 \
        /boot/grub/themes/catppuccin-macchiato-grub-theme/background.png \
        /etc/default/grub.d/zz-myconfig-catppuccin.cfg; do
        if [[ ! -r "$output" ]]; then printf 'MISSING: %s\n' "$output" >&2; failed=1; fi
    done
    python3 "$SCRIPT_DIR/lib/check-waybar-fonts.py" "$HOME/.config/waybar/config.jsonc" || failed=1
    (( failed == 0 )) || return 1
    if ! timeout 30s Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua"; then
        printf 'Hyprland configuration verification failed; KDE must be retained.\n' >&2
        return 1
    fi
    printf 'PASS: desktop dependencies and Hyprland configuration\n'
    [[ "$preflight" == false ]] || return 0
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || { printf 'Run this check from the new Hyprland desktop.\n' >&2; return 1; }
    output="$(hyprctl configerrors)"
    if [[ -n "$output" && "$output" != ok ]]; then printf '%s\n' "$output" >&2; failed=1; fi
    hyprctl monitors
    for unit in pipewire.service wireplumber.service xdg-desktop-portal.service xdg-desktop-portal-hyprland.service; do
        systemctl --user is-active "$unit" || failed=1
    done
    pgrep -u "$(id -u)" -x fcitx5 >/dev/null || failed=1
    [[ -n "$(fcitx5-remote -n 2>/dev/null)" ]] || failed=1
    [[ "${XMODIFIERS:-}" == '@im=fcitx' ]] || failed=1
    if [[ -n "${GTK_IM_MODULE:-}" ]]; then
        printf 'Unexpected global GTK_IM_MODULE=%s; log out/in after running repair-desktop.sh.\n' "$GTK_IM_MODULE" >&2
        failed=1
    fi
    wpctl status
    nmcli general status
    return "$failed"
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then check_main "$@"; fi

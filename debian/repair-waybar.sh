#!/usr/bin/env bash
# Focused font/style repair; does not touch GRUB, themes, packages, or other apps.
# shellcheck disable=SC1091
set -Eeuo pipefail
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/install.sh"
source "$SCRIPT_DIR/lib/install-appearance.sh"
work_dir=""
trap 'if [[ -n "$work_dir" ]]; then rm -rf -- "$work_dir"; fi' EXIT
[[ "$EUID" -ne 0 ]] || die 'Run as your normal user, without sudo.'
[[ "$(uname -s)" == Linux ]] || die 'Run on the installed Debian system.'
[[ "${XDG_CONFIG_HOME:-$HOME/.config}" == "$HOME/.config" ]] || die 'This profile requires ~/.config.'
mkdir -p "$STATE_DIR"
exec > >(tee -a "$STATE_DIR/repair-waybar.log") 2>&1
link_tree "$PROFILE_DIR/.config/waybar" "$HOME/.config/waybar"
backup_and_link "$PROFILE_DIR/.local/bin/waybar-start.sh" "$HOME/.local/bin/waybar-start.sh"
backup_and_link "$PROFILE_DIR/.local/bin/waybar-hyprland.py" "$HOME/.local/bin/waybar-hyprland.py"
backup_and_link "$PROFILE_DIR/.local/bin/desktop-session-start.sh" "$HOME/.local/bin/desktop-session-start.sh"
fc-cache -f
if ! python3 "$SCRIPT_DIR/lib/check-waybar-fonts.py" "$HOME/.config/waybar/config.jsonc" --quiet; then
    sudo -v
    work_dir="$(mktemp -d)"
    ensure_desktop_nerd_font "$work_dir" "$SCRIPT_DIR"
fi
python3 "$SCRIPT_DIR/lib/check-waybar-fonts.py" "$HOME/.config/waybar/config.jsonc"
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    bash "$HOME/.local/bin/waybar-start.sh" --restart
else
    printf 'Waybar configuration updated. Log in to Hyprland to load it.\n'
fi

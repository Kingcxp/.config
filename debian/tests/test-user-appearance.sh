#!/usr/bin/env bash
# Uses real gsettings/dconf in an isolated database. No desktop or system settings are changed.
set -Eeuo pipefail
TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"
TEST_WORK="$(mktemp -d)"
trap 'rm -rf -- "$TEST_WORK"' EXIT
mkdir -p "$TEST_WORK/config"
env -u DBUS_SESSION_BUS_ADDRESS XDG_CONFIG_HOME="$TEST_WORK/config" \
    dbus-run-session -- bash -s -- "$ROOT" "$TEST_WORK" <<'TEST'
set -Eeuo pipefail
root="$1"; work="$2"
gsettings set org.gnome.desktop.interface font-name 'Sans 9'
gsettings set org.gnome.desktop.interface text-scaling-factor 1.5
bash "$root/lib/user-appearance.sh" "$work/state"
[[ "$(gsettings get org.gnome.desktop.interface font-name)" == "'JetBrainsMono Nerd Font 12'" ]]
[[ "$(gsettings get org.gnome.desktop.interface text-scaling-factor)" == 1.0 ]]
[[ "$(gsettings get org.gnome.desktop.interface gtk-theme)" == "'catppuccin-macchiato-lavender-standard'" ]]
grep -q "font-name='Sans 9'" "$work/state/appearance-backups/"*/gnome-interface.dconf
before="$(find "$work/state/appearance-backups" -type d | wc -l)"
bash "$root/lib/user-appearance.sh" "$work/state"
[[ "$(find "$work/state/appearance-backups" -type d | wc -l)" == "$before" ]]
printf 'PASS: actual dconf font/scale/theme replacement, backup, and repeat application\n'
TEST

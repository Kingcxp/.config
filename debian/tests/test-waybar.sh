#!/usr/bin/env bash
# Real Fontconfig/Pango tests, including a legacy rule that replaces Latin digits.
# shellcheck disable=SC2016
set -Eeuo pipefail
TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" XDG_STATE_HOME="$work/state"
mkdir -p "$HOME/.config/fontconfig/conf.d" "$HOME/.config/waybar" "$HOME/.local/bin" "$work/bin" "$work/unscoped"
cp "$ROOT/config/.local/bin/waybar-hyprland.py" "$HOME/.local/bin/"
cp -a "$ROOT/config/.config/waybar/." "$HOME/.config/waybar/"
cp "$ROOT/config/.config/waybar/config.jsonc" "$work/unscoped/"
cat >"$HOME/.config/fontconfig/conf.d/99-legacy.conf" <<'FONTCONFIG'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <match target="pattern">
    <edit name="family" mode="assign" binding="strong"><string>Noto Sans CJK SC</string></edit>
  </match>
</fontconfig>
FONTCONFIG
if env -u FONTCONFIG_FILE python3 "$ROOT/lib/check-waybar-fonts.py" "$work/unscoped/config.jsonc" >"$work/unscoped.log" 2>&1; then
    printf 'FAIL: a legacy CJK replacement was not detected\n' >&2
    exit 1
fi
grep -q 'fontconfig substituted a different font' "$work/unscoped.log"
python3 "$ROOT/lib/check-waybar-fonts.py" "$HOME/.config/waybar/config.jsonc"
python3 - "$HOME/.config/waybar/config.jsonc" "$HOME/.config/waybar/style.css" <<'PY'
import json
import re
import sys

config = json.load(open(sys.argv[1], encoding="utf-8"))
style = open(sys.argv[2], encoding="utf-8").read()
assert config["height"] == 28, config["height"]
assert config["spacing"] == 6, config["spacing"]
assert config["hyprland/workspaces"]["move-to-monitor"] is True
battery = config["battery"]
power = config["battery#power"]
assert battery["interval"] == 5, battery["interval"]
assert battery["format-charging"].startswith("󰂄 "), battery["format-charging"]
assert battery["format-plugged"].startswith(" "), battery["format-plugged"]
assert battery["format-not-charging"].startswith(" "), battery["format-not-charging"]
assert battery["format-full"].startswith(" "), battery["format-full"]
assert "󰂄 " in power["format-charging"], power["format-charging"]
assert " " in power["format-plugged"], power["format-plugged"]
assert " " in power["format-not-charging"], power["format-not-charging"]
assert " " in power["format-full"], power["format-full"]
assert re.search(r"font-size:\s*15px\s*;", style)
assert re.search(r"#workspaces button\s*\{[^}]*margin-left:\s*6px", style)
assert re.search(r"#workspaces\s*\{[^}]*padding:\s*0 4px", style)
tray = re.search(r"#tray\s*\{([^}]*)\}", style, re.S)
tray_icons = re.search(r"#tray image\s*\{([^}]*)\}", style, re.S)
assert tray and re.search(r"color:\s*#cad3f5\s*;", tray[1]), "tray foreground must contrast the dark background"
assert tray_icons and re.search(r"color:\s*#cad3f5\s*;", tray_icons[1]), "symbolic tray icons must use the light foreground"
assert re.search(r"#battery\.plugged\s*\{[^}]*color:\s*#cad3f5", style, re.S)
assert re.search(r"#battery\.full\s*\{[^}]*color:\s*#a6da95", style, re.S)
print("PASS: click-to-focus workspace routing, battery state icons, 5-second refresh, 15px font, unchanged 28px bar, and clear tray/workspace contrast")
PY
printf 'PASS: scoped Waybar font rules defeat old CJK overrides; real Pango uses narrow JetBrainsMono digits\n'

# The startup path must request the managed CSS explicitly, regardless of an old
# style-dark.css and the user's inherited FONTCONFIG_FILE.
printf '* { font-family: "Noto Sans CJK SC"; }\n' >"$HOME/.config/waybar/style-dark.css"
cat >"$work/bin/waybar" <<'STUB'
#!/bin/sh
set -eu
test "$FONTCONFIG_FILE" = "$HOME/.config/waybar/fontconfig.conf"
test "$1" = --config && test "$2" = "$HOME/.config/waybar/config.jsonc"
test "$3" = --style && test "$4" = "$HOME/.config/waybar/style.css"
printf 'PASS: Waybar launcher pins both CSS and its font configuration\n'
STUB
chmod +x "$work/bin/waybar"
HYPRLAND_INSTANCE_SIGNATURE='' FONTCONFIG_FILE=/nonexistent PATH="$work/bin:$PATH" bash "$ROOT/config/.local/bin/waybar-start.sh"

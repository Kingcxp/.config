#!/usr/bin/env bash
# Real Fontconfig/Pango tests, including a legacy rule that replaces Latin digits.
# shellcheck disable=SC2016
set -Eeuo pipefail
TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" XDG_STATE_HOME="$work/state"
mkdir -p "$HOME/.config/fontconfig/conf.d" "$HOME/.config/waybar" "$work/bin" "$work/unscoped"
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
FONTCONFIG_FILE=/nonexistent PATH="$work/bin:$PATH" bash "$ROOT/config/.local/bin/waybar-start.sh"

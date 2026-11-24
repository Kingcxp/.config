#!/usr/bin/env bash
# Real Fontconfig/Pango/Kitty checks in an isolated user font configuration.
set -Eeuo pipefail
TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
export HOME="$work/home" XDG_CONFIG_HOME="$work/config" XDG_CACHE_HOME="$work/cache"
unset FONTCONFIG_FILE
mkdir -p "$HOME/.local/share/fonts/fandol" "$XDG_CONFIG_HOME/fontconfig"
cp -a "$ROOT/config/.config/fontconfig/." "$XDG_CONFIG_HOME/fontconfig/"
if [[ -n "${CJK_TEST_FANDOL_DIR:-}" ]]; then
    cp "$CJK_TEST_FANDOL_DIR/"*.otf "$HOME/.local/share/fonts/fandol/"
fi
fc-cache -f
python3 "$ROOT/lib/check-cjk-fonts.py"
[[ "$(fc-match -f '%{family}' 'SimSun:lang=zh-cn:charset=4e2d')" == 'Noto Serif CJK SC' ]]
if [[ "$(fc-match -f '%{family}' FandolKai)" == FandolKai ]]; then
    [[ "$(fc-match -f '%{family}' 'KaiTi:lang=zh-cn:charset=4e2d')" == FandolKai ]]
    printf 'PASS: registered FandolKai does not become the UI fallback; explicit document KaiTi remains available\n'
fi
python3 "$ROOT/lib/check-waybar-fonts.py" "$ROOT/config/.config/waybar/config.jsonc"
export CJK_KITTY_TEST="$TEST_DIR/kitty-cjk.py"
kitty +runpy 'import os, runpy; runpy.run_path(os.environ["CJK_KITTY_TEST"], run_name="__main__")'

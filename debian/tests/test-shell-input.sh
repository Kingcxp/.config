#!/usr/bin/env bash
# Integration checks with Debian's real Fish/im-config and a stub compositor.
# shellcheck disable=SC2016
set -Eeuo pipefail
TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" XDG_STATE_HOME="$work/home/.local/state"
export TERM=xterm-256color XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_DESKTOP=Hyprland
mkdir -p "$HOME/.config" "$work/bin"
cp -a "$ROOT/config/.config/fish" "$HOME/.config/fish"
ln -s "$ROOT/config/.config/hypr" "$HOME/.config/hypr"
ln -s "$ROOT/config/.xinputrc" "$HOME/.xinputrc"

# Use universal colors from an old installation and an inherited im-config value.
fish --no-config -c 'set --universal fish_color_command ff0000; set --universal --export GTK_IM_MODULE fcitx'
GTK_IM_MODULE=fcitx fish --interactive -c '
    test "$fish_color_command" = 8aadf4; or exit 1
    test "$fish_color_normal" = cad3f5; or exit 1
    test "$fish_color_error" = ed8796; or exit 1
    test "$fish_pager_color_prefix" = f5bde6; or exit 1
    if env | string match --quiet "GTK_IM_MODULE=*"
        echo "GTK_IM_MODULE leaked from Fish" >&2
        exit 1
    end
'
printf 'PASS: real Fish overrides old universal colors and does not export GTK_IM_MODULE\n'

cat >"$work/bin/start-hyprland" <<'STUB'
#!/bin/sh
set -eu
test "${GTK_IM_MODULE+present}" != present
test "$QT_IM_MODULE" = fcitx
test "$QT_IM_MODULES" = 'wayland;fcitx;ibus'
test "$XMODIFIERS" = '@im=fcitx'
test "$1" = -- && test "$2" = --config && test -r "$3"
printf 'PASS: session wrapper clears inherited GTK input and configures Qt 5/6\n'
STUB
chmod +x "$work/bin/start-hyprland"
GTK_IM_MODULE=fcitx PATH="$work/bin:$PATH" sh "$ROOT/session/myconfig-hyprland"

if [[ -r /etc/X11/Xsession.d/70im-config_launch ]]; then
    env -u GTK_IM_MODULE -u QT_IM_MODULE -u XMODIFIERS -u CLUTTER_IM_MODULE -u SDL_IM_MODULE -u IM_CONFIG_PHASE \
        dash -c '. /etc/X11/Xsession.d/70im-config_launch; test -z "${GTK_IM_MODULE:-}"'
    env -u GTK_IM_MODULE -u QT_IM_MODULE -u XMODIFIERS -u CLUTTER_IM_MODULE -u SDL_IM_MODULE -u IM_CONFIG_PHASE \
        XDG_CURRENT_DESKTOP=XFCE XDG_SESSION_DESKTOP=XFCE XDG_SESSION_TYPE=x11 \
        dash -c '. /etc/X11/Xsession.d/70im-config_launch; test "$GTK_IM_MODULE" = fcitx; test "$QT_IM_MODULE" = fcitx'
    printf 'PASS: real Debian im-config skips injection for Hyprland and retains X11 support\n'
else
    printf 'SKIP: Debian im-config is not installed\n'
fi

#!/usr/bin/env bash
set -Eeuo pipefail

# Do this before portal-using applications start, including when launched from a TTY.
unset GTK_IM_MODULE
systemctl --user unset-environment GTK_IM_MODULE || true
# D-Bus activation has no unset API; replace a previously inherited value with empty.
# The GTK portal keeps its explicit per-service Fcitx override for its dialogs.
dbus-update-activation-environment --systemd \
    GTK_IM_MODULE= \
    WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE \
    HYPRLAND_INSTANCE_SIGNATURE PATH XMODIFIERS SDL_IM_MODULE GLFW_IM_MODULE \
    XCURSOR_SIZE XCURSOR_THEME QT_QPA_PLATFORMTHEME QT_AUTO_SCREEN_SCALE_FACTOR QT_IM_MODULE QT_IM_MODULES \
    LIBVA_DRIVER_NAME LANG LANGUAGE
systemctl --user daemon-reload || true
systemctl --user try-restart xdg-desktop-portal.service xdg-desktop-portal-hyprland.service || true

gnome-keyring-daemon --start --components=secrets
waybar &
dunst &
hyprpaper &
hypridle &
fcitx5 --replace -d
nm-applet --indicator &
blueman-applet &
udiskie --tray &
/usr/libexec/polkit-mate-authentication-agent-1 &
kitty &

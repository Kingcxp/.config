#!/usr/bin/env python3
"""Render SDDM changes, preserving existing options; caller backs up/installs output."""
import argparse
import configparser
from pathlib import Path
import sys


def configure(path, user=None):
    config = configparser.ConfigParser(interpolation=None, strict=False)
    config.optionxform = str
    if path.exists():
        config.read_string(path.read_text(encoding="utf-8"))
    if user is not None:
        if not config.has_section("Last"):
            config.add_section("Last")
        config.set("Last", "Session", "/usr/share/wayland-sessions/myconfig-hyprland.desktop")
        config.set("Last", "User", user)
    else:
        if not config.has_section("Theme"):
            config.add_section("Theme")
        config.set("Theme", "Current", "catppuccin-macchiato-lavender")
        config.set("Theme", "Font", "JetBrainsMono Nerd Font,12,-1,5,50,0,0,0,0,0")
        config.set("Theme", "CursorTheme", "catppuccin-macchiato-lavender-cursors")
        config.set("Theme", "CursorSize", "32")
        if not config.has_section("General"):
            config.add_section("General")
        # SDDM defaults to qtvirtualkeyboard; keep it disabled in every theme.
        # An explicitly empty InputMethod disables it, including when Qt's module is installed.
        config.set("General", "InputMethod", "")
        for section in ("X11", "Wayland"):
            if not config.has_section(section):
                config.add_section(section)
            config.set(section, "EnableHiDPI", "true")
        # Preserve whether autologin was enabled, but retire its removed Plasma session.
        if config.has_section("Autologin") and config.get("Autologin", "User", fallback="").strip():
            config.set("Autologin", "Session", "myconfig-hyprland.desktop")
    return config


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--user")
    args = parser.parse_args()
    configure(args.path, args.user).write(sys.stdout, space_around_delimiters=False)

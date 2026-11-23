#!/usr/bin/env python3
"""Run with xvfb-run: verify actual SNI pixbuf pixels, not CSS foregrounds."""
from pathlib import Path
import subprocess
import sys
import tempfile

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk, Gtk


root = Path(__file__).resolve().parents[1]
Gtk.init([])
with tempfile.TemporaryDirectory() as work:
    directory = Path(work)
    subprocess.run([
        sys.executable, str(root / 'lib/build-tray-theme.py'),
        '/usr/share/icons/Papirus-Dark/22x22/panel',
        str(directory / 'Myconfig-Papirus-Dark'),
    ], check=True)
    theme = Gtk.IconTheme.new()
    theme.prepend_search_path(str(directory))
    theme.set_custom_theme('Myconfig-Papirus-Dark')
    for scale in (1, 2, 3):
        size = 20 * scale
        for name in ('input-keyboard-symbolic', 'blueman-tray',
                     'blueman-tray-symbolic', 'blueman-tray-active',
                     'blueman-tray-active-symbolic', 'blueman-tray-disabled',
                     'blueman-tray-disabled-symbolic', 'fcitx-pinyin-panel',
                     'nm-signal-75', 'nm-device-wired'):
            info = theme.lookup_icon(name, size, Gtk.IconLookupFlags.FORCE_SIZE)
            assert info and str(directory) in info.get_filename(), (name, size)
            pixbuf = info.load_icon()
            # Waybar 0.12 uses this exact pixbuf -> Cairo surface path. A GTK
            # image created from an icon name instead would hide this regression.
            surface = Gdk.cairo_surface_create_from_pixbuf(pixbuf, scale, None)
            image = Gtk.Image.new_from_surface(surface)
            assert image.get_storage_type() == Gtk.ImageType.SURFACE
            pixels = pixbuf.get_pixels()
            channels = pixbuf.get_n_channels()
            colors = []
            for y in range(pixbuf.get_height()):
                for x in range(pixbuf.get_width()):
                    offset = y * pixbuf.get_rowstride() + x * channels
                    if channels == 3 or pixels[offset + 3] > 64:
                        colors.append(tuple(pixels[offset:offset + 3]))
            assert colors, (name, size, 'empty artwork')
            target = (202, 211, 245)
            assert all(max(abs(c - t) for c, t in zip(color, target)) <= 4
                       for color in colors), (name, size, colors[:10])
            if 'disabled' in name:
                # Preserve a visibly distinct disabled state.
                assert max(pixels[3::channels]) < 200, (name, size)
    # Desktop icons still inherit from the full system theme.
    inherited = theme.lookup_icon('folder', 48, Gtk.IconLookupFlags.FORCE_SIZE)
    assert inherited and '/Papirus-Dark/' in inherited.get_filename(), inherited
print('PASS: light keyboard/Bluetooth/Fcitx/network SNI image pixels at 1x/2x/3x, disabled opacity, and desktop icon fallback')

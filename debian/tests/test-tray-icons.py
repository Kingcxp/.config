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
                     'fcitx-pinyin', 'nm-signal-75', 'nm-device-wired',
                     'network-wireless-signal-weak-symbolic',
                     'network-wireless-signal-excellent-symbolic',
                     'drive-removable-media-usb-panel'):
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
    # The application's actual default lookup must select the panel-only USB
    # artwork. Desktop file manager device icons retain their original style.
    Gtk.IconTheme.get_default().prepend_search_path(str(directory))
    Gtk.Settings.get_default().set_property('gtk-icon-theme-name', 'Myconfig-Papirus-Dark')
    from udiskie.tray import Icons
    assert Icons().get_icon_name('media') == 'drive-removable-media-usb-panel'
    device = theme.lookup_icon('drive-removable-media', 22, Gtk.IconLookupFlags.FORCE_SIZE)
    assert device and '/Papirus-Dark/' in device.get_filename(), device
print('PASS: light keyboard/Bluetooth/Fcitx/network/USB pixels at 1x/2x/3x, actual udiskie icon selection, disabled opacity, and desktop icon fallback')

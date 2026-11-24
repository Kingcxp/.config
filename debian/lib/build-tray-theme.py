#!/usr/bin/env python3
"""Make Papirus' light panel artwork usable by Waybar's pixbuf-based SNI tray.

GTK does not apply CSS foreground colors to Waybar 0.12's Cairo surfaces.
In particular, loading a -symbolic icon as a pixbuf leaves its dark default ink.
Use light panel counterparts, including at fractional/HiDPI scale factors.
All other desktop icons continue to come from the installed Papirus-Dark theme.
"""
from pathlib import Path
import re
import sys
import tempfile
import xml.etree.ElementTree as ET


def build(source, destination):
    aliases = {
        'input-keyboard': 'input-keyboard-virtual-on',
        'input-keyboard-symbolic': 'input-keyboard-virtual-on',
        'bluetooth-symbolic': 'bluetooth-active',
        'bluetooth-active-symbolic': 'bluetooth-active',
        'bluetooth-connected-symbolic': 'bluetooth-active',
        'bluetooth-disabled-symbolic': 'bluetooth-disabled',
        'bluetooth-disconnected-symbolic': 'bluetooth-disabled',
        'blueman-tray-symbolic': 'bluetooth-active',
        'blueman-tray-active-symbolic': 'bluetooth-active',
        'blueman-tray-disabled-symbolic': 'bluetooth-disabled',
    }
    for name in ('fcitx-pinyin-panel', 'nm-signal-75', *aliases.values()):
        if not (source / f'{name}.svg').is_file():
            raise RuntimeError(f'Missing Papirus panel icon: {source}/{name}.svg; install papirus-icon-theme')
    prefixes = ('blueman', 'bluetooth', 'fcitx', 'input-keyboard', 'nm-', 'network-', 'udiskie')
    icons = {path.stem: path for path in source.glob('*.svg')
             if path.is_file() and path.stem.startswith(prefixes)}
    # nm-applet/Fcitx versions may request symbolic names or the IM name without
    # the -panel suffix. Include the real network status artwork with its signal,
    # secure/disabled/error states, rather than replacing it with one static icon.
    for directory in ('status', 'devices', 'apps'):
        for path in (source.parent / 'symbolic' / directory).glob('*.svg'):
            if path.stem.startswith(('network-', 'fcitx')) and path.is_file():
                icons[path.stem] = path
    for name, path in list(icons.items()):
        if name.startswith('fcitx-') and name.endswith('-panel'):
            icons.setdefault(name.removesuffix('-panel'), path)
    icons.update({name: source / f'{original}.svg' for name, original in aliases.items()})
    # Keep Papirus' original USB panel artwork; use the same icon style as the
    # other status icons while recoloring its foreground for the dark bar.
    usb_icon = source / 'drive-removable-media-usb-panel.svg'
    if not usb_icon.is_file():
        raise RuntimeError(f'Missing Papirus USB tray artwork: {usb_icon}')
    icons['drive-removable-media-usb-panel'] = usb_icon
    artwork = {}
    for name, path in icons.items():
        svg = path.read_text(encoding='utf-8')
        # The panel artwork has explicit light ink. Preserve warning colors and
        # disabled-state opacity, and add a viewBox for scalable theme lookup.
        svg = re.sub('#dfdfdf', '#cad3f5', svg, flags=re.I)
        if 'viewBox=' not in svg:
            svg = svg.replace('<svg ', '<svg viewBox="0 0 22 22" ', 1)
        ET.fromstring(svg)
        artwork[f'scalable/status/{name}.svg'] = svg
    artwork['index.theme'] = '''[Icon Theme]
Name=Myconfig-Papirus-Dark
Comment=Papirus-Dark with light Macchiato tray icons
Inherits=Papirus-Dark,hicolor
Directories=scalable/status

[scalable/status]
Size=22
MinSize=8
MaxSize=256
Type=Scalable
Context=Status
'''
    for relative, content in artwork.items():
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=target.parent, delete=False) as handle:
            handle.write(content)
            temporary = Path(handle.name)
        temporary.replace(target)
    print(f'Built {len(icons)} light panel icons; desktop fallback: Papirus-Dark')


if __name__ == '__main__':
    try:
        if len(sys.argv) != 3:
            raise RuntimeError('Usage: build-tray-theme.py PAPIRUS_PANEL_DIRECTORY OUTPUT_DIRECTORY')
        build(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, RuntimeError, ET.ParseError) as error:
        sys.exit(str(error))

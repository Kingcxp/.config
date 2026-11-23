#!/usr/bin/env python3
"""Report real top-bar icon sources without dumping application pixmap bytes."""
import os
from pathlib import Path
import subprocess
import sys


def probe():
    # Waybar is a Wayland panel. A fresh GTK diagnostic must not select X11
    # just because its environment also contains a valid XWayland DISPLAY.
    os.environ['GDK_BACKEND'] = 'wayland'
    import gi
    gi.require_version('Gtk', '3.0')
    gi.require_version('Gdk', '3.0')
    from gi.repository import Gdk, Gio, GLib, Gtk

    Gdk.set_allowed_backends('wayland')
    ready, _ = Gtk.init_check([])
    if not ready:
        raise RuntimeError('Cannot connect to the running desktop')
    theme = Gtk.IconTheme.get_default()
    theme_name = Gtk.Settings.get_default().get_property('gtk-icon-theme-name')
    print('GTK backend: ' + type(Gdk.Display.get_default()).__name__, flush=True)
    print('GTK icon theme: ' + theme_name, flush=True)
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    def call(name, path, method, value):
        return bus.call_sync(name, path, 'org.freedesktop.DBus.Properties', method,
                             value, None, Gio.DBusCallFlags.NONE, 3000, None).unpack()[0]

    entries = call('org.kde.StatusNotifierWatcher', '/StatusNotifierWatcher', 'Get',
                   GLib.Variant('(ss)', ('org.kde.StatusNotifierWatcher', 'RegisteredStatusNotifierItems')))
    for entry in entries:
        name, _, path = entry.partition('/')
        try:
            properties = call(name, '/' + path if path else '/StatusNotifierItem', 'GetAll',
                              GLib.Variant('(s)', ('org.kde.StatusNotifierItem',)))
            item_id = properties.get('Id', '')
            if not any(word in item_id.lower() for word in ('fcitx', 'nm-applet', 'network')):
                continue
            icon = properties.get('IconName', '')
            own_path = properties.get('IconThemePath', '')
            sizes = [(item[0], item[1]) for item in properties.get('IconPixmap', [])]
            print(f'Tray {item_id}: IconName={icon!r}, IconThemePath={own_path!r}, pixmaps={sizes}', flush=True)
            if icon and Path(icon).is_file():
                print(f'  source: application file {icon}', flush=True)
            elif icon:
                for size in (20, 40):
                    info = None
                    if own_path:
                        app_theme = Gtk.IconTheme.new()
                        app_theme.set_search_path([own_path])
                        info = app_theme.lookup_icon(icon, size, Gtk.IconLookupFlags.FORCE_SIZE)
                    if not info:
                        info = theme.lookup_icon(icon, size, Gtk.IconLookupFlags.FORCE_SIZE)
                    print(f'  source at {size}px: {info.get_filename() if info else "not found"}', flush=True)
            elif sizes:
                print('  source: application-generated pixels (Fcitx uses TrayTextColor)', flush=True)
        except GLib.Error as error:
            print(f'WARNING: cannot inspect {entry}: {error.message}', flush=True)
    if theme_name != 'Myconfig-Papirus-Dark':
        print('WARNING: GTK reports a different theme name; inspect the actual icon source paths above. Configuration deployment has completed.', flush=True)


def main():
    if '--probe' in sys.argv:
        probe()
        return
    # Query GTK using the running Waybar's environment, including its session bus
    # and XDG paths, rather than silently probing a different terminal environment.
    own_uid = os.getuid()
    found = False
    for process in sorted(Path('/proc').glob('[0-9]*')):
        try:
            if process.stat().st_uid != own_uid or (process / 'comm').read_text().strip() != 'waybar':
                continue
            if (process / 'stat').read_text().rpartition(')')[2].split()[0] == 'Z':
                continue
            found = True
            environment = dict(item.split('=', 1) for item in
                               (process / 'environ').read_bytes().decode(errors='replace').split('\0') if '=' in item)
            print(f'Waybar PID {process.name}; actual icon sources:', flush=True)
            subprocess.run([sys.executable, str(Path(__file__).resolve()), '--probe'],
                           env=environment | {'NO_AT_BRIDGE': '1'}, check=True, timeout=15)
        except FileNotFoundError:
            continue
    if not found:
        raise RuntimeError('No Waybar process owned by the current user')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'Icon source check failed: {error}', file=sys.stderr)
        sys.exit(1)

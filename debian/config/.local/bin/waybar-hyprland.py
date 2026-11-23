#!/usr/bin/env python3
"""Run Debian's Waybar with workspace IPC compatible with Hyprland's Lua config.

Waybar 0.12 sends legacy dispatches even when Hyprland uses its Lua provider.
Only this child receives a private IPC socket; the real compositor, its event
stream, and other applications are unchanged. Native Lua requests pass through.
"""
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import tempfile


def lua_quote(value):
    return '"' + ''.join(
        '\\' + char if char in ('"', '\\') else
        f'\\{ord(char):03d}' if ord(char) < 32 else char
        for char in value
    ) + '"'


def translate(request):
    match = re.fullmatch(
        rb'(?P<flags>[a-z]*/)?dispatch (?P<name>workspace|focusworkspaceoncurrentmonitor|togglespecialworkspace)(?: (?P<arg>[^\r\n]*))?',
        request,
    )
    if not match:
        return request
    name = match['name'].decode()
    arg = (match['arg'] or b'').decode('utf-8')
    if name == 'togglespecialworkspace':
        dispatch = f'hl.dsp.workspace.toggle_special({lua_quote(arg) if arg else ""})'
    else:
        if not arg:
            return request
        monitor = ', on_current_monitor = true' if name == 'focusworkspaceoncurrentmonitor' else ''
        dispatch = f'hl.dsp.focus({{ workspace = {lua_quote(arg)}{monitor} }})'
    return (match['flags'] or b'/') + b'dispatch ' + dispatch.encode('utf-8')


def relay(connection, upstream):
    request = connection.recv(65536)
    if not request:
        return
    converted = translate(request)
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as compositor:
        compositor.settimeout(3)
        compositor.connect(str(upstream))
        compositor.sendall(converted)
        while chunk := compositor.recv(65536):
            connection.sendall(chunk)
            if converted != request and not chunk.startswith(b'ok'):
                print('Waybar workspace dispatch reply: ' + chunk.decode(errors='replace'), file=sys.stderr, flush=True)


def main():
    args = ['waybar', *sys.argv[1:]]
    signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
    if not signature:
        os.execvp(args[0], args)
    info = subprocess.run(['hyprctl', 'systeminfo'], check=True, capture_output=True, text=True, timeout=5).stdout
    if not re.search(r'^\s*configProvider:\s*lua\s*$', info, re.M):
        os.execvp(args[0], args)
    runtime_dir = os.environ.get('XDG_RUNTIME_DIR')
    if not runtime_dir:
        raise RuntimeError('XDG_RUNTIME_DIR is missing; start Waybar from the running desktop')
    runtime = Path(runtime_dir) / 'hypr'
    if Path(signature).name != signature:
        raise RuntimeError('Invalid Hyprland instance signature')
    upstream = runtime / signature
    if not (upstream / '.socket.sock').is_socket() or not (upstream / '.socket2.sock').is_socket():
        raise RuntimeError('Hyprland IPC sockets are missing; start Waybar from the running desktop')

    # mkdtemp creates a private 0700 directory; cleanup removes only our own files.
    with tempfile.TemporaryDirectory(prefix='myconfig-wb-', dir=runtime) as private:
        directory = Path(private)
        (directory / '.socket2.sock').symlink_to(upstream / '.socket2.sock')
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
            listener.bind(str(directory / '.socket.sock'))
            (directory / '.socket.sock').chmod(0o600)
            listener.listen(8)
            listener.settimeout(0.2)
            child = subprocess.Popen(args, env=os.environ | {'HYPRLAND_INSTANCE_SIGNATURE': directory.name})

            def stop(_signum, _frame):
                child.terminate()

            signal.signal(signal.SIGTERM, stop)
            signal.signal(signal.SIGINT, stop)
            print('Waybar: enabled private Hyprland Lua workspace IPC compatibility.', flush=True)
            try:
                while child.poll() is None:
                    try:
                        connection, _ = listener.accept()
                    except socket.timeout:
                        continue
                    with connection:
                        connection.settimeout(3)
                        try:
                            relay(connection, upstream / '.socket.sock')
                        except (OSError, UnicodeError) as error:
                            print(f'Waybar IPC error: {error}', file=sys.stderr, flush=True)
            finally:
                if child.poll() is None:
                    child.terminate()
                    try:
                        child.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        child.kill()
                child.wait()
            return child.returncode if child.returncode >= 0 else 128 - child.returncode


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'Cannot start Waybar: {error}', file=sys.stderr)
        sys.exit(1)

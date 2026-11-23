#!/usr/bin/env python3
"""Exercise the child environment, Unix transport, Lua dispatches, and cleanup."""
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import unittest


HELPER = Path(__file__).resolve().parents[1] / 'config/.local/bin/waybar-hyprland.py'


@unittest.skipUnless(sys.platform == 'linux', 'requires Linux Unix sockets')
class WaybarIpcTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='wb-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.instance = self.root / 'hypr/real'
        self.instance.mkdir(parents=True)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.env = os.environ | {
            'XDG_RUNTIME_DIR': str(self.root),
            'HYPRLAND_INSTANCE_SIGNATURE': 'real',
            'PATH': str(self.bin) + ':' + os.environ['PATH'],
            'TEST_ROOT': str(self.root),
        }
        self.write_executable('hyprctl', '#!/bin/sh\nprintf "configProvider: lua\\n"\n')

    def write_executable(self, name, content):
        path = self.bin / name
        path.write_text(content, encoding='utf-8')
        path.chmod(0o755)

    def test_legacy_buttons_use_lua_while_queries_and_events_pass_unchanged(self):
        received = []
        errors = []
        requests = [
            b'j/monitors',
            b'dispatch workspace 2',
            b'dispatch focusworkspaceoncurrentmonitor 10',
            b'dispatch togglespecialworkspace magic',
            b'dispatch hl.dsp.focus({ workspace = "3" })',
        ]
        expected = [
            b'j/monitors',
            b'/dispatch hl.dsp.focus({ workspace = "2" })',
            b'/dispatch hl.dsp.focus({ workspace = "10", on_current_monitor = true })',
            b'/dispatch hl.dsp.workspace.toggle_special("magic")',
            b'dispatch hl.dsp.focus({ workspace = "3" })',
        ]
        large_reply = b'[' + b' ' * 100000 + b']'
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as commands, socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as events:
            commands.bind(str(self.instance / '.socket.sock'))
            commands.listen()
            commands.settimeout(5)
            events.bind(str(self.instance / '.socket2.sock'))
            events.listen()
            events.settimeout(5)

            def server():
                try:
                    for request in expected:
                        connection, _ = commands.accept()
                        with connection:
                            data = connection.recv(65536)
                            received.append(data)
                            connection.sendall(large_reply if request == b'j/monitors' else b'ok' if data == request else b'Invalid Lua syntax')
                    connection, _ = events.accept()
                    with connection:
                        connection.sendall(b'workspacev2>>2,2\n')
                except Exception as error:
                    errors.append(error)

            thread = threading.Thread(target=server, daemon=True)
            thread.start()
            self.write_executable('waybar', '''#!/usr/bin/env python3
import os
from pathlib import Path
import socket
root = Path(os.environ['TEST_ROOT'])
signature = os.environ['HYPRLAND_INSTANCE_SIGNATURE']
assert signature != 'real'
folder = root / 'hypr' / signature
assert folder.stat().st_mode & 0o777 == 0o700
assert (folder / '.socket.sock').stat().st_mode & 0o777 == 0o600
assert (folder / '.socket2.sock').resolve() == root / 'hypr/real/.socket2.sock'
for request in ''' + repr(requests) + ''':
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.connect(str(folder / '.socket.sock'))
        client.sendall(request)
        reply = b''
        while chunk := client.recv(65536): reply += chunk
        assert reply == (b'[' + b' ' * 100000 + b']' if request == b'j/monitors' else b'ok'), reply
with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as events:
    events.connect(str(folder / '.socket2.sock'))
    assert events.recv(1024) == b'workspacev2>>2,2\\n'
''')
            result = subprocess.run([sys.executable, str(HELPER)], env=self.env, capture_output=True, text=True, timeout=10)
            thread.join(timeout=1)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(received, expected)
        self.assertEqual(errors, [])
        self.assertEqual(list((self.root / 'hypr').iterdir()), [self.instance])
        self.assertEqual(self.env['HYPRLAND_INSTANCE_SIGNATURE'], 'real')

    def test_legacy_config_does_not_use_a_proxy(self):
        self.write_executable('hyprctl', '#!/bin/sh\nprintf "configProvider: hyprlang\\n"\n')
        self.write_executable('waybar', '#!/bin/sh\ntest "$HYPRLAND_INSTANCE_SIGNATURE" = real\n')
        result = subprocess.run([sys.executable, str(HELPER)], env=self.env, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(list((self.root / 'hypr').iterdir()), [self.instance])


if __name__ == '__main__':
    unittest.main()

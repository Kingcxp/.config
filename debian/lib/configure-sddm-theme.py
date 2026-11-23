#!/usr/bin/env python3
"""Apply the small Debian Qt6 appearance fixes to the pinned SDDM archive."""
from pathlib import Path
import sys


def configure(root):
    for name, label in (("UserField.qml", "用户名"), ("PasswordField.qml", "密码")):
        path = root / "Components" / name
        text = path.read_text(encoding="utf-8")
        # Debian's Fusion style otherwise supplies nearly black placeholder text.
        if 'placeholderTextColor:' not in text:
            text = text.replace('  selectionColor: "#6E738D"',
                                '  selectionColor: "#6E738D"\n  placeholderTextColor: "#A5ADCB"\n  selectedTextColor: "#CAD3F5"')
        text = text.replace('placeholderText: "Username"', f'placeholderText: "{label}"')
        text = text.replace('placeholderText: "Password"', f'placeholderText: "{label}"')
        text = text.replace('radius: 3', 'radius: 6')
        path.write_text(text, encoding="utf-8")
    path = root / "Components" / "LoginPanel.qml"
    text = path.read_text(encoding="utf-8")
    text = text.replace('radius: 5', 'radius: 12').replace('radius: 3', 'radius: 6')
    text = text.replace('text: "Login"', 'text: "登录"')
    # Do not try to load an account icon while the optional avatar is hidden.
    text = text.replace('source: Qt.resolvedUrl("/var/lib/AccountsService/icons/" + user)',
                        'source: (config.UserIcon == "true" && user != "") ? Qt.resolvedUrl("/var/lib/AccountsService/icons/" + user) : ""')
    path.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    configure(Path(sys.argv[1]))

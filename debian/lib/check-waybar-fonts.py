#!/usr/bin/env python3
"""Check the actual regular/medium fonts, including every configured Waybar icon."""

import argparse
import json
from pathlib import Path
import subprocess
import sys


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)


def check(config, quiet=False):
    data = json.loads(Path(config).read_text(encoding="utf-8"))
    icons = {
        ord(char)
        for text in strings(data)
        for char in text
        if 0xE000 <= ord(char) <= 0xF8FF
        or 0xF0000 <= ord(char) <= 0xFFFFD
        or 0x100000 <= ord(char) <= 0x10FFFD
    }
    for weight in ("regular", "medium"):
        match = subprocess.check_output(
            ["fc-match", "-f", "%{family}\n%{file}\n", f"JetBrainsMono Nerd Font:weight={weight}"],
            text=True,
        ).splitlines()
        if len(match) != 2 or "JetBrainsMono Nerd Font" not in match[0].split(","):
            raise ValueError(f"{weight}: fontconfig substituted a different font: {match}")
        charset = subprocess.check_output(
            ["fc-query", "-f", "%{charset}", match[1]], text=True
        )
        ranges = []
        for token in charset.split():
            first, _, last = token.partition("-")
            ranges.append((int(first, 16), int(last or first, 16)))
        missing = sorted(code for code in icons if not any(a <= code <= b for a, b in ranges))
        if missing:
            raise ValueError(
                f"{match[1]} is missing Waybar icons: "
                + ", ".join(f"U+{code:04X}" for code in missing)
            )
        if not quiet:
            print(f"PASS Waybar {weight}: {match[1]} ({len(icons)} icon codepoints)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    try:
        check(args.config, args.quiet)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        if not args.quiet:
            print(f"Waybar font check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

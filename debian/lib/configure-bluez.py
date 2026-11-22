#!/usr/bin/env python3
"""Set BlueZ Experimental=true while preserving the rest of main.conf."""

from __future__ import annotations

import re
import sys
from pathlib import Path


SECTION = re.compile(r"^[ \t]*\[([^]]+)\][ \t]*(?:[;#].*)?(?:\r?\n)?$")
SETTING = re.compile(r"^([ \t]*Experimental[ \t]*=[ \t]*)(.*?)(\r?\n)?$", re.IGNORECASE)


def enable_experimental(contents: str) -> str:
    lines = contents.splitlines(keepends=True)
    general_start = None
    general_end = len(lines)

    for index, line in enumerate(lines):
        section = SECTION.match(line)
        if not section:
            continue
        if general_start is not None:
            general_end = index
            break
        if section.group(1).strip().lower() == "general":
            general_start = index

    newline = "\r\n" if "\r\n" in contents else "\n"
    if general_start is None:
        suffix = "" if not contents or contents.endswith(("\n", "\r")) else newline
        return f"{contents}{suffix}[General]{newline}Experimental=true{newline}"

    found = False
    for index in range(general_start + 1, general_end):
        match = SETTING.match(lines[index])
        if match and not lines[index].lstrip().startswith(("#", ";")):
            lines[index] = f"{match.group(1)}true{match.group(3) or ''}"
            found = True
    if not found:
        lines.insert(general_start + 1, f"Experimental=true{newline}")
    return "".join(lines)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {Path(sys.argv[0]).name} BLUEZ_MAIN_CONF", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    raw = path.read_bytes()
    contents = raw.decode("utf-8")
    updated = enable_experimental(contents)
    path.write_bytes(updated.encode("utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

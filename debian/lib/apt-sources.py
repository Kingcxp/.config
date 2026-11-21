#!/usr/bin/env python3
"""Inspect Debian 13 APT entries and switch archives with reversible backups."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
from datetime import datetime, timezone
from urllib.parse import urlsplit

MANAGED = "myconfig-debian.sources"
OFFICIAL = "https://deb.debian.org/debian"
MIRRORS = {
    "official": (OFFICIAL, "https://security.debian.org/debian-security"),
    "nju": ("https://mirror.nju.edu.cn/debian", "https://mirror.nju.edu.cn/debian-security"),
}
SUITES = {"trixie", "trixie-updates", "trixie-security", "trixie-backports",
          "stable", "stable-updates", "stable-security", "stable-backports"}


def fields_of(paragraph):
    fields, previous = {}, None
    for line in paragraph.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line[0].isspace() and previous:
            fields[previous] += " " + line.strip()
        elif ":" in line:
            key, value = line.split(":", 1)
            previous = key.lower()
            fields[previous] = value.strip()
    return fields


def is_debian(uri, fields=None):
    parsed = urlsplit(uri)
    return (parsed.scheme in {"http", "https", "ftp", "mirror+http", "mirror+https"}
            and (parsed.path.rstrip("/") in {"/debian", "/debian-security"}
                 or "debian-archive-keyring" in (fields or {}).get("signed-by", "")))


def managed_source(mirror):
    archive, security = MIRRORS[mirror]
    blocks = [f"# Managed by myconfig Debian installer. Mirror: {mirror}"]
    for suite in ("trixie", "trixie-updates", "trixie-security", "trixie-backports"):
        blocks.append("\n".join([
            "Types: deb", f"URIs: {security if suite.endswith('-security') else archive}",
            f"Suites: {suite}", "Components: main contrib non-free non-free-firmware",
            "Architectures: amd64 i386", "Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg",
        ]))
    return "\n\n".join(blocks) + "\n"


def switch_plan(root, mirror):
    """Disable old Debian entries, retain vendors, and select one complete archive."""
    paths = [root / "sources.list"]
    paths += sorted((root / "sources.list.d").glob("*.list"))
    paths += sorted((root / "sources.list.d").glob("*.sources"))
    changes = {}
    for uri, suite, fields in entries(root, True):
        if is_debian(uri, fields) and suite not in SUITES:
            raise ValueError(f"Unexpected Debian suite: {suite}; remove foreign-release entries first")
    for path in paths:
        if not path.is_file() or path.name == MANAGED:
            continue
        text = path.read_text(encoding="utf-8")
        if path.suffix == ".sources":
            parts = re.split(r"(\n\s*\n)", text)
            for i in range(0, len(parts), 2):
                fields = fields_of(parts[i])
                if fields.get("enabled", "yes").lower() == "no":
                    continue
                uris = fields.get("uris", "").split()
                selected = [is_debian(uri, fields) or uri.startswith("cdrom:") for uri in uris]
                if not any(selected):
                    continue
                if not all(selected):
                    raise ValueError(f"Mixed Debian/vendor URIs in {path}; split this stanza first")
                if not all(uri.startswith("cdrom:") for uri in uris):
                    unknown = set(fields.get("suites", "").split()) - SUITES
                    if unknown:
                        raise ValueError(f"Unexpected Debian suites in {path}: {sorted(unknown)}")
                block = parts[i]
                if re.search(r"(?im)^Enabled:", block):
                    block = re.sub(r"(?im)^Enabled:.*$", "Enabled: no", block)
                else:
                    block = block.rstrip("\n") + "\nEnabled: no\n"
                parts[i] = "# Disabled by myconfig; original is in the APT backup.\n" + block
            result = "".join(parts)
        else:
            lines = []
            for line in text.splitlines(keepends=True):
                match = re.match(r"^\s*deb(?:-src)?\s+(?:\[[^]]*\]\s+)?(\S+)\s+(\S+)", line)
                cdrom = re.match(r"^\s*deb(?:-src)?\s+.*cdrom:", line)
                if cdrom or (match and is_debian(match[1])):
                    if not cdrom and match[2] not in SUITES:
                        raise ValueError(f"Unexpected Debian suite in {path}: {match[2]}")
                    line = "# Disabled by myconfig: " + line
                lines.append(line)
            result = "".join(lines)
        if result != text:
            changes[path.relative_to(root).as_posix()] = result
    managed = root / "sources.list.d" / MANAGED
    if managed.exists() and not managed.read_text(encoding="utf-8").startswith("# Managed by myconfig"):
        raise ValueError(f"Refusing to replace unmanaged source: {managed}")
    changes[f"sources.list.d/{MANAGED}"] = managed_source(mirror)
    for relative in changes:
        if (root / relative).is_symlink():
            raise ValueError(f"Refusing to replace a source symlink: {root / relative}")
    return {p: text for p, text in changes.items()
            if not (root / p).exists() or (root / p).read_text(encoding="utf-8") != text}


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".myconfig-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def restore(root, backup):
    manifest = json.loads((backup / "manifest.json").read_text(encoding="utf-8"))
    for relative, existed in manifest.items():
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts or not (relative == "sources.list" or
                (len(path.parts) == 2 and path.parts[0] == "sources.list.d")):
            raise ValueError("Invalid path in APT backup")
        target = root / path
        if existed:
            atomic_write(target, (backup / path).read_text(encoding="utf-8"))
        else:
            target.unlink(missing_ok=True)


def apply_switch(root, mirror, backup_root):
    changes = switch_plan(root, mirror)
    backup_root.mkdir(parents=True, exist_ok=True, mode=0o700)
    prefix = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + f"-{os.getpid()}-"
    backup = Path(tempfile.mkdtemp(prefix=prefix, dir=backup_root))
    manifest = {}
    for relative in changes:
        old = root / relative
        manifest[relative] = old.exists()
        if old.exists():
            saved = backup / relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(old, saved)
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    try:
        for relative, text in changes.items():
            atomic_write(root / relative, text)
    except (OSError, KeyboardInterrupt):
        restore(root, backup)
        raise
    return backup


def entries(root, include_managed=False):
    paths = [root / "sources.list"]
    directory = root / "sources.list.d"
    paths += sorted(directory.glob("*.list")) + sorted(directory.glob("*.sources"))
    for path in paths:
        if not path.is_file() or (path.name == MANAGED and not include_managed):
            continue
        text = path.read_text(encoding="utf-8")
        if path.suffix == ".sources":
            for paragraph in re.split(r"\n\s*\n", text):
                fields = {}
                previous = None
                for line in paragraph.splitlines():
                    if not line.strip() or line.lstrip().startswith("#"):
                        continue
                    if line[0].isspace() and previous:
                        fields[previous] += " " + line.strip()
                    elif ":" in line:
                        key, value = line.split(":", 1)
                        previous = key.lower()
                        fields[previous] = value.strip()
                if fields.get("enabled", "yes").lower() == "no" or "deb" not in fields.get("types", "").split():
                    continue
                for uri in fields.get("uris", "").split():
                    for suite in fields.get("suites", "").split():
                        yield uri.rstrip("/"), suite, fields
        else:
            for line in text.splitlines():
                match = re.match(r"^\s*deb\s+(?:\[([^]]*)\]\s+)?(\S+)\s+(\S+)\s+([^#]+)", line)
                if not match:
                    continue
                options, uri, suite, components = match.groups()
                fields = {"components": components}
                for option in (options or "").split():
                    if "=" not in option:
                        continue
                    key, value = option.split("=", 1)
                    key = {"arch": "architectures", "arch+": "architectures-add", "arch-": "architectures-remove"}.get(key, key)
                    fields[key] = value.replace(",", " ")
                yield uri.rstrip("/"), suite, fields


def supplemental(root):
    existing = list(entries(root))
    blocks = ["# Managed by myconfig Debian installer. Existing sources are retained."]
    for suite in ("trixie", "trixie-updates", "trixie-security", "trixie-backports"):
        uri = "https://security.debian.org/debian-security" if suite.endswith("-security") else OFFICIAL
        components = ["main"] if suite.endswith("-backports") else ["main", "contrib", "non-free", "non-free-firmware"]
        groups = {}
        for component in components:
            missing = {"amd64", "i386"}
            for old_uri, existing_suite, fields in existing:
                parsed = urlsplit(old_uri)
                # A vendor's "trixie main" is not a Debian archive (e.g. Tailscale).
                is_debian = parsed.scheme in {"http", "https", "ftp"} and (
                    parsed.path.rstrip("/") in {"/debian", "/debian-security"}
                    or "debian-archive-keyring" in fields.get("signed-by", "")
                )
                if not is_debian:
                    continue
                if existing_suite != suite or component not in fields.get("components", "").split():
                    continue
                arches = set(fields.get("architectures", "amd64 i386").split())
                arches.update(fields.get("architectures-add", "").split())
                arches.difference_update(fields.get("architectures-remove", "").split())
                missing.difference_update(arches)
            if missing:
                groups.setdefault(tuple(sorted(missing)), []).append(component)
        # APT requires the same Signed-By for entries sharing URI and suite.
        same_source = [fields for old_uri, old_suite, fields in existing if old_uri == uri and old_suite == suite]
        key = same_source[0].get("signed-by") if same_source else "/usr/share/keyrings/debian-archive-keyring.gpg"
        for arches, wanted in groups.items():
            block = ["Types: deb", f"URIs: {uri}", f"Suites: {suite}", "Components: " + " ".join(wanted), "Architectures: " + " ".join(arches)]
            if key:
                block.append("Signed-By: " + key)
            blocks.append("\n".join(block))
    return "\n\n".join(blocks) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("/etc/apt"))
    parser.add_argument("--has", metavar="URI")
    parser.add_argument("--switch", choices=MIRRORS)
    parser.add_argument("--backup-root", type=Path, default=Path("/var/backups/myconfig-debian/apt"))
    parser.add_argument("--restore", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.restore:
        restore(args.root, args.restore)
        return 0
    if args.switch:
        if args.dry_run:
            print(json.dumps(switch_plan(args.root, args.switch), ensure_ascii=False, indent=2))
        else:
            print(apply_switch(args.root, args.switch, args.backup_root))
        return 0
    if args.has:
        return 0 if any(uri == args.has.rstrip("/") for uri, _, _ in entries(args.root, True)) else 1
    print(supplemental(args.root), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

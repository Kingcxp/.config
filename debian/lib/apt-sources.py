#!/usr/bin/env python3
"""Read active APT entries; emit only missing Debian 13 components/architectures."""
import argparse
from pathlib import Path
import re
from urllib.parse import urlsplit

MANAGED = "myconfig-debian.sources"
OFFICIAL = "https://deb.debian.org/debian"


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
    args = parser.parse_args()
    if args.has:
        return 0 if any(uri == args.has.rstrip("/") for uri, _, _ in entries(args.root, True)) else 1
    print(supplemental(args.root), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

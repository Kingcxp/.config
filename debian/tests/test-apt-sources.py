#!/usr/bin/env python3
"""Offline tests of source handling; never reads or writes the real /etc/apt."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("apt_sources", Path(__file__).resolve().parents[1] / "lib/apt-sources.py")
sources = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sources)


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "sources.list.d").mkdir()

    def write(self, name, text):
        (self.root / name).write_text(text, encoding="utf-8")

    def test_empty_adds_all_suites_and_architectures(self):
        result = sources.supplemental(self.root)
        self.assertIn("Suites: trixie-security", result)
        self.assertIn("Suites: trixie-backports", result)
        self.assertIn("Architectures: amd64 i386", result)

    def test_disabled_deb822_and_deb_src_do_not_count(self):
        self.write("sources.list.d/disabled.sources", "Types: deb\nURIs: https://deb.debian.org/debian\nSuites: trixie\nComponents: main\nEnabled: no\n")
        self.write("sources.list", "deb-src https://deb.debian.org/debian trixie main\n# deb https://deb.debian.org/debian trixie main\n")
        self.assertIn("Components: main contrib non-free non-free-firmware", sources.supplemental(self.root))

    def test_architecture_filter_supplements_i386(self):
        self.write("sources.list", "deb [arch=amd64] https://deb.debian.org/debian trixie main contrib non-free non-free-firmware\n")
        first = sources.supplemental(self.root).split("\n\n")[1]
        self.assertIn("Architectures: i386", first)
        self.assertNotIn("Signed-By", first)  # Inherit this URI/suite's legacy key policy.

    def test_vendor_trixie_main_is_not_debian_main(self):
        self.write("sources.list", "deb https://pkgs.tailscale.com/stable/debian trixie main\n")
        self.assertIn("Components: main contrib non-free non-free-firmware", sources.supplemental(self.root))

    def test_managed_file_is_stable_across_reruns(self):
        first = sources.supplemental(self.root)
        self.write("sources.list.d/myconfig-debian.sources", first)
        self.assertEqual(first, sources.supplemental(self.root))

    def test_signed_by_is_preserved_for_same_uri_suite(self):
        self.write("sources.list.d/base.sources", "Types: deb\nURIs: https://deb.debian.org/debian\nSuites: trixie\nComponents: main\nSigned-By: /custom/debian.gpg\n")
        first = sources.supplemental(self.root).split("\n\n")[1]
        self.assertIn("Signed-By: /custom/debian.gpg", first)
        self.assertNotIn("Components: main", first)

    def test_architecture_add_and_remove(self):
        self.write("sources.list.d/base.sources", "Types: deb\nURIs: https://deb.debian.org/debian\nSuites: trixie\nComponents: main\nArchitectures: amd64 i386\nArchitectures-Remove: i386\n")
        result = sources.supplemental(self.root)
        self.assertIn("Components: main\nArchitectures: i386", result)


if __name__ == "__main__":
    unittest.main()

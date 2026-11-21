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

    def test_switch_disables_old_sources_and_cdrom_but_keeps_vendor(self):
        self.write("sources.list", "deb cdrom:[Debian GNU/Linux 13] trixie main\n"
                   "deb https://old.example/debian stable main\n"
                   "deb https://pkgs.tailscale.com/stable/debian trixie main\n")
        changes = sources.switch_plan(self.root, "nju")
        self.assertIn("# Disabled by myconfig: deb cdrom:", changes["sources.list"])
        self.assertIn("# Disabled by myconfig: deb https://old.example/debian", changes["sources.list"])
        self.assertIn("\ndeb https://pkgs.tailscale.com/stable/debian", changes["sources.list"])
        managed = changes["sources.list.d/myconfig-debian.sources"]
        self.assertIn("https://mirror.nju.edu.cn/debian-security", managed)
        self.assertIn("Suites: trixie-backports", managed)
        self.assertNotIn("Suites: stable", managed)

    def test_deb822_mixed_file_keeps_vendor_stanza(self):
        self.write("sources.list.d/base.sources", "Types: deb deb-src\nURIs: https://deb.debian.org/debian\n"
                   "Suites: trixie trixie-updates\nComponents: main\n\n"
                   "Types: deb\nURIs: https://packages.microsoft.com/repos/code\nSuites: stable\nComponents: main\n")
        changed = sources.switch_plan(self.root, "nju")["sources.list.d/base.sources"]
        self.assertEqual(changed.count("Enabled: no"), 1)
        self.assertTrue(changed.endswith("Suites: stable\nComponents: main\n"))

    def test_switch_restore_and_repeat_are_exact(self):
        original = "# Original\ndeb https://deb.debian.org/debian trixie main\n"
        self.write("sources.list", original)
        backup = sources.apply_switch(self.root, "nju", self.root / "backups")
        self.assertEqual(sources.switch_plan(self.root, "nju"), {})
        self.assertEqual({uri for uri, _, _ in sources.entries(self.root, True)},
                         {"https://mirror.nju.edu.cn/debian", "https://mirror.nju.edu.cn/debian-security"})
        sources.apply_switch(self.root, "official", self.root / "backups")
        self.assertNotIn("mirror.nju.edu.cn", (self.root / "sources.list.d/myconfig-debian.sources").read_text())
        sources.restore(self.root, backup)
        self.assertEqual((self.root / "sources.list").read_text(), original)
        self.assertFalse((self.root / "sources.list.d/myconfig-debian.sources").exists())

    def test_foreign_debian_suite_rejected_before_any_write(self):
        original = "deb https://deb.debian.org/debian sid main\n"
        self.write("sources.list", original)
        with self.assertRaises(ValueError):
            sources.apply_switch(self.root, "nju", self.root / "backups")
        self.assertEqual((self.root / "sources.list").read_text(), original)
        self.assertFalse((self.root / "backups").exists())

    def test_mixed_uri_stanza_and_unmanaged_target_rejected(self):
        self.write("sources.list.d/base.sources", "Types: deb\nURIs: https://deb.debian.org/debian https://vendor.example/repo\nSuites: trixie\nComponents: main\n")
        with self.assertRaises(ValueError):
            sources.switch_plan(self.root, "nju")
        (self.root / "sources.list.d/base.sources").unlink()
        self.write("sources.list.d/myconfig-debian.sources", "# User owned\n")
        with self.assertRaises(ValueError):
            sources.switch_plan(self.root, "official")


if __name__ == "__main__":
    unittest.main()

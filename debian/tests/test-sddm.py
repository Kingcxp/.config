#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("sddm", Path(__file__).resolve().parents[1] / "lib/configure-sddm.py")
sddm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sddm)


class SddmTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "sddm.conf"

    def test_defaults_do_not_enable_autologin(self):
        config = sddm.configure(self.path)
        self.assertEqual(config["Theme"]["Current"], "debian-maui")
        self.assertFalse(config.has_section("Autologin"))

    def test_existing_theme_and_autologin_migrate_without_losing_options(self):
        self.path.write_text("[Theme]\nCurrent=breeze\nCursorTheme=bibata\n[Autologin]\nUser=tester\nSession=plasma.desktop\nRelogin=false\n[General]\nDisplayServer=x11\n")
        config = sddm.configure(self.path)
        self.assertEqual(config["Theme"]["Current"], "debian-maui")
        self.assertEqual(config["Theme"]["CursorTheme"], "bibata")
        self.assertEqual(config["Autologin"]["Session"], "myconfig-hyprland.desktop")
        self.assertEqual(config["Autologin"]["User"], "tester")
        self.assertEqual(config["General"]["DisplayServer"], "x11")

    def test_state_preselects_new_session(self):
        self.path.write_text("[Last]\nSession=/usr/share/wayland-sessions/plasma.desktop\nUser=old\n")
        config = sddm.configure(self.path, "tester")
        self.assertEqual(config["Last"]["User"], "tester")
        self.assertEqual(config["Last"]["Session"], "/usr/share/wayland-sessions/myconfig-hyprland.desktop")


if __name__ == "__main__":
    unittest.main()

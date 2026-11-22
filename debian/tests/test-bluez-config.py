#!/usr/bin/env python3
import importlib.util
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "lib" / "configure-bluez.py"
SPEC = importlib.util.spec_from_file_location("configure_bluez", SCRIPT)
assert SPEC and SPEC.loader
BLUEZ = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BLUEZ)


class BluezConfigTests(unittest.TestCase):
    def test_sets_existing_value_and_preserves_other_settings(self):
        source = "# preserve me\n[General]\nExperimental=false\nName=ThinkBook\n[Policy]\nAutoEnable=true\n"
        result = BLUEZ.enable_experimental(source)
        self.assertIn("Experimental=true\nName=ThinkBook", result)
        self.assertIn("# preserve me", result)
        self.assertIn("[Policy]\nAutoEnable=true", result)

    def test_adds_missing_setting_to_general(self):
        self.assertEqual(BLUEZ.enable_experimental("[General]\nName=ThinkBook\n"),
                         "[General]\nExperimental=true\nName=ThinkBook\n")

    def test_appends_general_section_when_absent(self):
        self.assertEqual(BLUEZ.enable_experimental("[Policy]\r\nAutoEnable=true\r\n"),
                         "[Policy]\r\nAutoEnable=true\r\n[General]\r\nExperimental=true\r\n")

    def test_ignores_commented_setting(self):
        self.assertEqual(BLUEZ.enable_experimental("[General]\n# Experimental=false\n"),
                         "[General]\nExperimental=true\n# Experimental=false\n")

    def test_is_idempotent(self):
        configured = BLUEZ.enable_experimental("[General]\nName=ThinkBook\n")
        self.assertEqual(BLUEZ.enable_experimental(configured), configured)


if __name__ == "__main__":
    unittest.main()

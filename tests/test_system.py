"""System files: placeholders, and only the selected components' files."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from installer import components, model, system


class Render(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.file = Path(self.tmp.name) / "power.conf"

    def tearDown(self):
        self.tmp.cleanup()

    def test_battery_name(self):
        self.file.write_text("z /sys/class/power_supply/@BATTERY@/x 0664 root wheel -\n")
        self.assertEqual(model.render(self.file, {"battery": "BAT1"}),
                         b"z /sys/class/power_supply/BAT1/x 0664 root wheel -\n")

    def test_no_value_is_an_error_not_an_empty_path(self):
        self.file.write_text("@BATTERY@\n")
        for hw in ({}, {"battery": ""}, {"battery": True}):
            with self.assertRaises(ValueError):
                model.render(self.file, hw)

    def test_plain_files_are_untouched(self):
        self.file.write_bytes(b"user@host # email@example.com\n")
        self.assertEqual(model.render(self.file, {}), b"user@host # email@example.com\n")


class Selection(unittest.TestCase):
    def files(self, on: set[str]) -> set[str]:
        with mock.patch.object(components, "selected", return_value=on):
            return {str(f.relative_to(model.SYSTEM)) for f in model.system_files()}

    def test_everything_is_every_file(self):
        self.assertEqual(self.files(set(components.load())),
                         {str(f.relative_to(model.SYSTEM)) for f in model.system_files(every=True)})

    def test_a_desktop_gets_no_laptop_files(self):
        cat = components.load()
        got = self.files(set(cat) - {"laptop", "nvidia-laptop", "asus-fx516pm-headset-mic", "vpn", "ollama"})
        self.assertEqual(got, {"etc/polkit-1/rules.d/50-pkexec-keep.rules"})


class LaterNotes(unittest.TestCase):
    def test_boot_only_tmpfiles_say_so(self):
        notes = system.later_notes("/etc/tmpfiles.d/headset-mic.conf", "w! /sys/x - - - - 1\n")
        self.assertEqual(len(notes), 1)
        self.assertIn("next boot", notes[0])

    def test_tmpfiles_without_boot_lines_say_nothing(self):
        self.assertEqual(system.later_notes("/etc/tmpfiles.d/x.conf", "w /sys/x - - - - 1\n"), [])

    def test_modprobe_waits_for_a_reboot(self):
        self.assertEqual(len(system.later_notes("/etc/modprobe.d/x.conf", "")), 1)


class PlatformProfileRule(unittest.TestCase):
    """The profile's mode is set when its device appears: tmpfiles runs too early for it."""

    rule = model.SYSTEM / "etc/udev/rules.d/90-quickshell-power.rules"

    def test_a_copied_rule_re_adds_the_device(self):
        self.assertIn("/etc/udev/rules.d", system.SYSTEM_APPLY)
        self.assertIn("platform-profile", " ".join(system.SYSTEM_APPLY["/etc/udev/rules.d"]))

    def test_rule_sets_the_profile_file(self):
        text = self.rule.read_text()
        self.assertIn('SUBSYSTEM=="platform-profile"', text)
        self.assertIn("/sys/firmware/acpi/platform_profile", text)
        self.assertIn("chgrp wheel", text)

    def test_laptop_component_installs_the_rule(self):
        self.assertIn("etc/udev/rules.d/90-quickshell-power.rules", components.load()["laptop"]["system"])


if __name__ == "__main__":
    unittest.main()


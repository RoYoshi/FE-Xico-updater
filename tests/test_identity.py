#!/usr/bin/env python3
"""FE-Xico Updater presents FE-XicoOS identity while keeping upstream attribution."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def user_strings(path):
    """i18n()/i18nc() literals from a QML or C++ file: the text users see."""
    text = path.read_text()
    return re.findall(r'i18nc?\(\s*(?:"[^"]*"\s*,\s*)?"((?:[^"\\]|\\.)*)"', text)


class IdentityTests(unittest.TestCase):
    def test_visible_text_does_not_present_bazzite_or_uupd_as_current(self):
        files = list((ROOT / "src").rglob("*.qml")) + [ROOT / "src/main.cpp", ROOT / "src/native_operation.cpp"]
        for path in files:
            for string in user_strings(path):
                if "Original Bazzite Updater contributor" in string:
                    continue  # historical credit, kept on purpose
                self.assertNotRegex(string, r"(?i)bazzite|uupd|universal blue", f"{path.name}: {string}")

    def test_bundled_os_about_data_is_fe_xicoos(self):
        about = json.loads((ROOT / "src/resources/KAboutData_OS.json").read_text())
        self.assertEqual(about["displayName"], "FE-XicoOS")
        self.assertNotRegex(json.dumps(about), r"(?i)bazzite|uupd|universal blue")
        self.assertEqual({c["name"] for c in about["credits"]}, {"Fedora Project", "KDE community"})
        self.assertTrue(about["programLogo"].endswith(".png"), "the retired SVG hat is not referenced")

    def test_appstream_describes_the_native_backend(self):
        metainfo = (ROOT / "io.github.royoshi.fexicoupdater.metainfo.xml").read_text()
        description = metainfo[metainfo.index("<description>"):metainfo.index("</description>")]
        self.assertNotRegex(description, r"(?i)uupd|universal blue")
        self.assertIn("FE-XicoOS", description)
        # Release history is history: the 0.1.0 notes may still mention uupd.
        self.assertIn('<release version="0.1.0"', metainfo)

    def test_upstream_attribution_and_licences_are_kept(self):
        main = (ROOT / "src/main.cpp").read_text()
        self.assertIn("© 2025-2026 Robert French; FE-Xico adaptation by RoYoshi", main)
        self.assertIn('"Gareth Widlansky"', main)
        readme = (ROOT / "README.md").read_text()
        self.assertIn("## Credits and licensing", readme)
        self.assertIn("https://github.com/rfrench3/bazzite_updater", readme)
        self.assertTrue((ROOT / "LICENSES/GPL-2.0-or-later.txt").is_file())
        self.assertIn("SPDX-FileCopyrightText: 2025 Robert French", (ROOT / "src/pages/Main.qml").read_text())

    def test_no_generic_or_universal_blue_leftovers(self):
        self.assertFalse((ROOT / "src/resources/Tux.png").exists())
        self.assertNotIn("Tux", (ROOT / "src/resources.qrc").read_text())
        self.assertNotIn("ublue-os", (ROOT / ".devcontainer/devcontainer.json").read_text())
        self.assertNotRegex((ROOT / ".gitignore").read_text(), r"(?i)bazzite|uupd")


if __name__ == "__main__":
    unittest.main()

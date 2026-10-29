"""Source contract for the FE-XicoOS auto-update checkbox in Settings."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class AutoUpdateCheckboxTests(unittest.TestCase):
    def test_real_timer_state_and_confirmed_checkbox(self):
        qml = (ROOT / "src/pages/settings/Settings.qml").read_text()
        self.assertIn("FC.FormCheckDelegate", qml)
        self.assertIn("checked: AutoUpdateSettings.enabled", qml)
        self.assertIn("AutoUpdateSettings.refresh()", qml)
        self.assertIn("AutoUpdateSettings.setAutoUpdatesEnabled(requested)", qml)
        self.assertIn("NEVER automatically reboots", qml)
        self.assertIn("activeStartPicker", qml)
        self.assertIn("activeEndPicker", qml)
        self.assertIn("AutoUpdateSettings.setActiveHours", qml)

    def test_polkit_required_and_no_generic_shell(self):
        cpp = (ROOT / "src/auto_update_settings.cpp").read_text()
        self.assertIn('QStringLiteral("/usr/bin/pkexec")', cpp)
        self.assertIn('QStringLiteral("/usr/bin/bash"), helper,', cpp)
        self.assertIn('QStringLiteral("--disable-internal-agent")', cpp)
        self.assertIn('QStringLiteral("is-enabled")', cpp)
        self.assertNotIn('startDetached', cpp)
        self.assertNotIn('"/bin/sh"', cpp)
        self.assertIn('fe-xicoos-auto-update.timer', cpp)
        self.assertIn('setActiveHours(int startHour, int endHour)', cpp)

if __name__ == "__main__":
    unittest.main()

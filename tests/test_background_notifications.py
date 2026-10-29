"""Contract: check results send KDE notifications when updater is inactive."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = (ROOT / "src/native_operation.cpp").read_text()
HDR = (ROOT / "src/auto_update_settings.h").read_text()

class BackgroundNotificationsTests(unittest.TestCase):
    def test_background_check_states_and_error(self):
        for fragment in ("QGuiApplication::applicationState()", "Qt::ApplicationActive",
                         "org.freedesktop.Notifications", "Notify",
                         'outcome == u"up-to-date"', 'outcome == u"update-available"',
                         "if (!success)", 'if (action == u"check"_s)'):
            self.assertIn(fragment, SRC)

    def test_hour_settings_invokable(self):
        self.assertIn("Q_PROPERTY(int startHour", HDR)
        self.assertIn("Q_PROPERTY(int endHour", HDR)
        self.assertIn("Q_INVOKABLE void setActiveHours", HDR)

if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Source contracts for the refined UI: honest state, real actions, shared tokens."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"


def read(relative):
    return (SRC / relative).read_text()


class RefineContracts(unittest.TestCase):
    def test_brand_colours_live_only_in_the_token_file(self):
        for path in SRC.rglob("*.qml"):
            if path.name == "FeXico.qml":
                continue
            self.assertNotRegex(path.read_text(), r'(?i)#(00FF00|FF00FF|C0C0C0)\b', path.name)
        tokens = read("components/FeXico.qml")
        self.assertIn("pragma Singleton", tokens)
        cmake = read("CMakeLists.txt")
        self.assertIn("QT_QML_SINGLETON_TYPE TRUE", cmake)
        for name in ("FeXico", "Panel", "StatusPanel", "FactRow", "SectionLabel"):
            self.assertIn(f"components/{name}.qml", cmake)
        self.assertIn("pages/system_update/status.js", cmake)
        self.assertIn("preview_tour.cpp", cmake)

    def test_progress_is_never_invented(self):
        panel = read("components/StatusPanel.qml")
        bar = panel[panel.index("QQC2.ProgressBar {"):]
        bar = bar[:bar.index("}")]
        # Determinate only from bootc's own position and total, relayed by the backend.
        self.assertIn("visible: root.busy", bar)
        self.assertIn("indeterminate: !root.progressKnown", bar)
        self.assertIn("value: root.progressKnown ? root.progress.value : 0", bar)
        self.assertIn("progress.known === true", panel)
        self.assertNotIn("Animation", bar)
        page = read("pages/system_update/SystemUpdate.qml")
        self.assertIn("progress: AppState.progress", page)
        for name in ("pages/system_update/SystemUpdate.qml", "pages/rebase_helper/RebaseHelper.qml"):
            self.assertNotIn("ProgressBar", read(name))
        native = read("native_operation.cpp")
        # "known" is set only where bootc supplied a total the value does not exceed.
        self.assertEqual(native.count('out[u"known"_s] = true;'), 2)
        self.assertIn("bytesTotal > 0 && bytes <= bytesTotal", native)
        self.assertIn("stepsTotal >= 2 && steps <= stepsTotal", native)
        # No rates, time estimates or overall percentages.
        for text in (panel, page, native):
            self.assertNotRegex(text, r"(?i)\b(remaining|eta|per second|percent)\b|%1 ?%")
        # Progress never decides: the result line alone sets the outcome.
        self.assertIn("appState.clearProgress();", native)

    def test_up_to_date_is_only_the_verified_state(self):
        page = read("pages/system_update/SystemUpdate.qml")
        self.assertEqual(page.count('i18n("Up to date")'), 1)
        self.assertIn('case "up-to-date": return i18n("Up to date");', page)
        status = read("pages/system_update/status.js")
        self.assertIn('if (facts.lastCheckOutcome === "up-to-date")\n        return "up-to-date";', status)

    def test_every_primary_action_runs_real_code(self):
        page = read("pages/system_update/SystemUpdate.qml")
        run = page[page.index("function runPrimary()"):page.index("function primaryAvailable()")]
        for call in ("SystemUpdateBackend.checkUpdates(finished)", "SystemUpdateBackend.runUpdate(finished)",
                     "applicationWindow().openRestartDialog()", "applicationWindow().showDeployments()",
                     "consoleDrawer.drawerOpen = true"):
            self.assertIn(call, run)
        main = read("pages/Main.qml")
        self.assertIn("function openRestartDialog()", main)
        self.assertIn("rebootDialog.open()", main)
        self.assertIn("deploymentsAction.trigger()", main)

    def test_startup_reads_status_only_and_never_in_tests(self):
        main = read("pages/Main.qml")
        startup = main[main.index("Component.onCompleted: {"):]
        startup = startup[:startup.index("\n    }\n")]
        self.assertIn("SystemUpdateBackend.refreshStatus(", startup)
        for forbidden in ("checkUpdates", "runUpdate", "rollbackImage", "rebootSystem"):
            self.assertNotIn(forbidden, startup)
        self.assertIn("QmlSmokeTest || PreviewMode || !UserSettings.readStatusOnStart", startup)
        settings = (SRC / "components/kConfig/user_settings.h").read_text()
        self.assertIn("bool readStatusOnStart = true;", settings)
        self.assertIn("UserSettings.readStatusOnStart", read("pages/settings/Settings.qml"))

    def test_rollback_stays_separate_confirmed_and_honest(self):
        page = read("pages/rebase_helper/RebaseHelper.qml")
        self.assertIn("An OS rollback is not a backup.", page)
        self.assertIn("Kirigami.MessageType.Warning", page)
        self.assertIn("id: rollbackConfirm", page)
        self.assertIn("rollbackConfirm.checked", page)
        self.assertIn("Nothing has been rolled back yet.", page)
        self.assertNotIn("rollbackImage", read("pages/system_update/SystemUpdate.qml"))

    def test_settings_have_no_decorative_rows_and_keep_disclosure(self):
        settings = read("pages/settings/Settings.qml")
        self.assertNotIn("Updater Preferences", settings)
        self.assertIn("NEVER automatically reboots", settings)

    def test_previews_are_labelled_and_side_effect_free(self):
        tour = read("preview_tour.cpp")
        for forbidden in ("QProcess", "runNativeOperation", "rebootSystem", "startDetached", "systemctl"):
            self.assertNotIn(forbidden, tour)
        main_qml = read("pages/Main.qml")
        self.assertIn("Simulated preview", main_qml)
        main_cpp = read("main.cpp")
        self.assertIn('setContextProperty(u"QmlSmokeTest"_s, smokeTest || previewMode)', main_cpp)
        self.assertIn('setContextProperty(u"PreviewMode"_s, previewMode)', main_cpp)

    def test_large_text_has_a_scalable_fallback_for_terminus(self):
        tokens = read("components/FeXico.qml")
        self.assertIn('/terminus/i.test(defaultFamily) ? "Hack" : defaultFamily', tokens)
        self.assertIn("FeXico.headingFamily(", read("components/StatusPanel.qml"))

    def test_reduced_motion_is_respected(self):
        tokens = read("components/FeXico.qml")
        self.assertIn("Kirigami.Units.longDuration > 1 ? duration : 0", tokens)
        for path in SRC.rglob("*.qml"):
            text = path.read_text()
            for match in re.finditer(r"(NumberAnimation|ColorAnimation)\s*\{[^}]*\}", text, re.S):
                block = match.group(0)
                if "duration:" in block and path.name not in ("Main.qml",):
                    self.assertIn("FeXico.motion(", block, f"{path.name}: {block[:60]}")


if __name__ == "__main__":
    unittest.main()

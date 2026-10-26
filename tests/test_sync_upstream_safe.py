#!/usr/bin/env python3
"""Regression tests for the guarded upstream sync workflow; stdlib only."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SYNC = Path(__file__).resolve().parents[1] / "scripts/sync_upstream_safe.py"


class GuardedUpstreamSyncTest(unittest.TestCase):
    def run_git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, check=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.decode().strip()

    def put(self, path, value):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(value, encoding="utf-8")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.run_git("init", "-b", "main")
        self.run_git("config", "user.name", "FE-XicoOS test")
        self.run_git("config", "user.email", "test@example.invalid")
        self.put("src/components/console/console.cpp", "original console\n")
        self.put("src/components/console/console.h", "original header\n")
        self.put("src/pages/Main.qml", "FE-Xico UI base\n")
        self.put("src/resources/config.ini", "update=FE-Xico\n")
        self.put("src/components/console/old.cpp", "old code\n")
        self.put("README.md", "FE-Xico branding\n")
        self.run_git("add", ".")
        self.run_git("commit", "-m", "shared base")
        self.run_git("checkout", "-b", "upstream")
        self.put("src/components/console/console.cpp", "upstream bug fix\n")
        self.put("src/components/console/console.h", "upstream interface\n")
        self.put("src/components/console/new.cpp", "new upstream feature\n")
        self.put("src/pages/Main.qml", "Bazzite new UI\n")
        self.put("src/resources/config.ini", "update=bazzite-uupd\n")
        self.put("README.md", "Bazzite branding\n")
        (self.root / "src/components/console/old.cpp").unlink()
        self.run_git("add", "-A")
        self.run_git("commit", "-m", "upstream update")
        self.run_git("checkout", "main")
        self.put("src/components/console/console.h", "FE-Xico customized interface\n")
        self.put("README.md", "FE-Xico branding customized\n")
        self.run_git("add", "-A")
        self.run_git("commit", "-m", "fork customizations")

    def test_copies_untouched_only_and_reports_deferred(self):
        result = subprocess.run([sys.executable, str(SYNC), "--upstream", "upstream"],
                                cwd=self.root, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "src/components/console/console.cpp").read_text(),
                         "upstream bug fix\n")
        self.assertEqual((self.root / "src/components/console/new.cpp").read_text(),
                         "new upstream feature\n")
        self.assertEqual((self.root / "src/components/console/console.h").read_text(),
                         "FE-Xico customized interface\n")
        self.assertEqual((self.root / "src/pages/Main.qml").read_text(),
                         "FE-Xico UI base\n")
        self.assertEqual((self.root / "src/resources/config.ini").read_text(),
                         "update=FE-Xico\n")
        self.assertTrue((self.root / "src/components/console/old.cpp").exists())
        self.assertEqual((self.root / "README.md").read_text(),
                         "FE-Xico branding customized\n")
        report = (self.root / "docs/upstream-sync-report.md").read_text()
        self.assertIn("console.cpp", report)
        self.assertIn("also modified by FE-Xico", report)
        self.assertIn("upstream deletion", report)
        self.assertIn("src/resources/config.ini", report)
        self.assertIn("manual port", report)
        self.assertEqual(len(self.run_git("diff", "--name-only").splitlines()), 1)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""The packaged application icon is a complete raster hicolor set built from the pinned original."""
import hashlib
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP_ID = "io.github.royoshi.fexicoupdater"
SIZES = (16, 22, 24, 32, 48, 64, 128, 256, 512)


def png_info(path):
    data = path.read_bytes()[:26]
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{path} is not a PNG"
    width, height, _depth, colour = struct.unpack(">IIBB", data[16:26])
    return width, height, colour


class AppIconTests(unittest.TestCase):
    def test_original_is_pinned(self):
        digest, name = (ROOT / "branding/SHA256SUMS").read_text().split()
        self.assertEqual(name, "fe-xico-updater-icon-original.png")
        self.assertEqual(hashlib.sha256((ROOT / "branding" / name).read_bytes()).hexdigest(), digest)

    def test_hicolor_set_and_window_fallback(self):
        for size in SIZES:
            self.assertEqual(png_info(ROOT / f"icons/hicolor/{size}x{size}/apps/{APP_ID}.png"), (size, size, 6))
        self.assertEqual(png_info(ROOT / "src/resources/FE-XicoUpdater.png"), (512, 512, 6))

    def test_installed_as_raster_and_never_as_png_wrapped_svg(self):
        self.assertFalse((ROOT / f"{APP_ID}.svg").exists())
        cmake = (ROOT / "CMakeLists.txt").read_text()
        self.assertIn('install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/icons/hicolor"', cmake)
        self.assertNotIn(f"{APP_ID}.svg", cmake)
        spec = (ROOT / "fe-xico-updater.spec").read_text()
        self.assertIn("%{_kf6_datadir}/icons/hicolor/*/apps/%{appid}.png", spec)
        self.assertIn(f"Icon={APP_ID}", (ROOT / f"{APP_ID}.desktop").read_text())


if __name__ == "__main__":
    unittest.main()

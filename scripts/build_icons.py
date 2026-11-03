#!/usr/bin/env python3
"""Build the FE-Xico Updater application icons from RoYoshi's original artwork.

Developer tool only (needs Pillow); the CMake build installs the committed PNGs.

    python3 scripts/build_icons.py

The artwork is never redrawn, recoloured, sharpened or stretched: the script trims
fully transparent margins, centres the art on a square transparent canvas and
scales it down proportionally. Raster stays raster (no PNG-inside-SVG files).
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / "branding/fe-xico-updater-icon-original.png"
APP_ID = "io.github.royoshi.fexicoupdater"
SIZES = (16, 22, 24, 32, 48, 64, 128, 256, 512)
MARGIN = 1 / 32                       # transparent margin on each side
WINDOW_FALLBACK = ROOT / "src/resources/FE-XicoUpdater.png"   # qrc ":/updaterLogo"
WINDOW_FALLBACK_SIZE = 512


def main() -> int:
    expected = (ROOT / "branding/SHA256SUMS").read_text().split()[0]
    if hashlib.sha256(ORIGINAL.read_bytes()).hexdigest() != expected:
        sys.exit("branding/fe-xico-updater-icon-original.png differs from branding/SHA256SUMS")
    art = Image.open(ORIGINAL)
    if art.mode != "RGBA":
        sys.exit("the original must be RGBA with real transparency")
    art = art.crop(art.getchannel("A").getbbox())
    side = round(max(art.size) / (1 - 2 * MARGIN))
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(art, ((side - art.width) // 2, (side - art.height) // 2))
    targets = [(ROOT / f"icons/hicolor/{size}x{size}/apps/{APP_ID}.png", size) for size in SIZES]
    targets.append((WINDOW_FALLBACK, WINDOW_FALLBACK_SIZE))
    for path, size in targets:
        if size > side:
            sys.exit(f"refusing to upscale to {size}px")
        path.parent.mkdir(parents=True, exist_ok=True)
        square.resize((size, size), Image.LANCZOS).save(path, optimize=True)
        print(path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

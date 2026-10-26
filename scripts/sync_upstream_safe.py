#!/usr/bin/env python3
"""Propose *only* untouched upstream files; never merge FE-Xico customizations.

Run from an up-to-date checkout of FE-Xico-Updater's main branch. Git history
must contain the common ancestor with rfrench3/bazzite-updater.
This script changes the worktree for a human-reviewed PR, NOT the base branch.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys

# Only portable upstream implementation and test files are eligible.
# Packaging, identity, generated UI assets, shell/system update commands,
# translations with a different app domain, CI and submodules are never synced.
ALLOW_PREFIXES = ("src/", "tests/", "cmake/")
ALLOW_SUFFIXES = (".cpp", ".h", ".qml", ".js", ".cmake", ".txt", ".sh")
PROTECTED_PREFIXES = (
    "src/resources/",
    "src/components/kConfig/",
    "src/pages/system_update/",
    "src/pages/rebase_helper/",
    "src/pages/rebase_page/",
    "src/pages/other_utils/",
    "src/pages/settings/",
)
PROTECTED_FILES = frozenset({
    "src/main.cpp",
    "src/CMakeLists.txt",
    "src/resources.qrc",
    "src/pages/Main.qml",
    "src/pages/AboutDataOS.qml",
    "src/pages/AboutDataApp.qml",
    "src/components/AppDialog.qml",
    "src/components/customFormcards/FCSystemInfo.qml",
    "src/components/customFormcards/FCOsRelease.qml",
    "src/components/console/ConsoleDrawer.qml",
})
MAX_FILE_BYTES = 256 * 1024


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(["git", *args], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=check)


def safe_path(path: str) -> bool:
    parts = PurePosixPath(path).parts
    return bool(parts) and path != "" and not path.startswith("/") and (
        ".." not in parts and "." not in parts
    )


def eligible(path: str) -> bool:
    if not safe_path(path):
        return False
    if path in PROTECTED_FILES or path.startswith(PROTECTED_PREFIXES):
        return False
    if not path.startswith(ALLOW_PREFIXES):
        return False
    if not path.endswith(ALLOW_SUFFIXES):
        return False
    return True


def locally_changed(base: str, path: str) -> bool:
    result = git("diff", "--quiet", base, "HEAD", "--", path, check=False)
    if result.returncode not in (0, 1):
        raise RuntimeError(f"Unable to compare fork history: {path}")
    return result.returncode == 1


def read_blob(upstream: str, path: str) -> bytes | None:
    # git ls-tree returns nothing for upstream-deleted files.
    result = git("ls-tree", "-z", upstream, "--", path).stdout
    if not result:
        return None
    line = result.rstrip(b"\x00").split(b"\t", 1)
    if len(line) != 2 or line[1] != os.fsencode(path):
        raise RuntimeError(f"Unexpected git tree entry for {path}")
    mode, obj_type, _, *_ = line[0].decode("ascii").split()
    if mode not in ("100644", "100755") or obj_type != "blob":
        raise RuntimeError(f"Refusing special git tree entry: {path}")
    blob = git("show", f"{upstream}:{path}").stdout
    if len(blob) > MAX_FILE_BYTES or b"\x00" in blob:
        raise ValueError(f"oversized or binary upstream file: {path}")
    return blob


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--upstream", default="bazzite-upstream/main")
    p.add_argument("--report", default="docs/upstream-sync-report.md")
    opts = p.parse_args()
    upstream = opts.upstream

    if git("status", "--porcelain").stdout.strip():
        raise RuntimeError("Start from a clean FE-Xico-Updater checkout")
    base = git("merge-base", "HEAD", upstream).stdout.decode().strip()
    fork_sha = git("rev-parse", "HEAD").stdout.decode().strip()
    upstream_sha = git("rev-parse", upstream).stdout.decode().strip()

    paths_raw = git("diff", "--name-only", "-z", "--no-renames",
                    base, upstream).stdout
    paths = [os.fsdecode(part) for part in paths_raw.split(b"\x00") if part]
    copied: list[str] = []
    withheld: list[tuple[str, str]] = []

    for path in paths:
        if not eligible(path):
            withheld.append((path, "protected customization or outside allowlist"))
            continue
        if locally_changed(base, path):
            withheld.append((path, "also modified by FE-Xico since fork point"))
            continue
        try:
            blob = read_blob(upstream, path)
        except (RuntimeError, ValueError) as error:
            withheld.append((path, str(error)))
            continue
        if blob is None:
            withheld.append((path, "upstream deletion: manual review required"))
            continue
        target = Path(path)
        if target.is_symlink() or (target.exists() and not target.is_file()):
            withheld.append((path, "not an ordinary destination file"))
            continue
        if target.exists() and target.read_bytes() == blob:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(blob)
        copied.append(path)

    report = [
        "# FE-Xico-Updater upstream sync review",
        "",
        "**This is a proposal, not an automatic merge.** No FE-Xico-specific",
        "configurations, UI, branding, packaging or update commands were overwritten.",
        "",
        f"- Fork base: `{fork_sha}`",
        f"- Upstream: `rfrench3/bazzite-updater@{upstream_sha}`",
        f"- Common ancestor: `{base}`",
        f"- Files safely copied into this proposal: **{len(copied)}**",
        f"- Paths withheld for manual review: **{len(withheld)}**",
        "",
        "## Proposed upstream files (must pass application and CI review)",
        "",
        *([f"- `{path}`" for path in copied] or ["- None"]),
        "",
        "## NOT applied (manual port required where relevant)",
        "",
        *([f"- `{path}` — {reason}" for path, reason in withheld] or ["- None"]),
        "",
        "## Before merging",
        "",
        "1. Review upstream changes for correctness, licensing and security.",
        "2. Port useful changes from protected files manually, retaining FE-Xico branding",
        "   and Fedora bootc service commands, controller support and config paths.",
        "3. Update the CMake/QML wiring for any new upstream components if required.",
        "4. Run Fedora 44 build, QML launch, update/rollback and polkit tests.",
        "5. Only after the updater PR is merged, update the pinned submodule in",
        "   `RoYoshi/FE-Xico` through a separate reviewed FE-XicoOS CI change.",
        "6. Never auto-publish or rebase the installed FE-XicoOS image from this PR.",
        "",
        "Upstream changes to modified FE-Xico files are **reported, not discarded**.",
        "",
    ]
    report_path = Path(opts.report)
    if not safe_path(opts.report):
        raise ValueError("Invalid report path")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(report), encoding="utf-8")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("\n".join(report[:18]) + "\n")
    print(f"Fork {fork_sha[:12]}, upstream {upstream_sha[:12]}: "
          f"{len(copied)} files proposed, {len(withheld)} withheld.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"Upstream sync refused: {exc}", file=sys.stderr)
        sys.exit(1)

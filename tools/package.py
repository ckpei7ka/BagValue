#!/usr/bin/env python3
"""Build a release zip that mirrors what BigWigsMods/packager produces."""
from __future__ import annotations

import hashlib
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "dist"
IGNORE = {
    ".git", ".github", "dist", "tools", "docs", "__pycache__",
    "README.md", "CHANGELOG.md", "LICENSE", ".luacheckrc", ".gitignore", ".pkgmeta",
}


def package_name() -> str:
    toc = sorted(ROOT.glob("*.toc"))[0]
    return toc.stem


def version() -> str:
    toc = sorted(ROOT.glob("*.toc"))[0]
    for line in toc.read_text(encoding="utf-8-sig").splitlines():
        if line.lower().startswith("## version:"):
            return line.split(":", 1)[1].strip()
    return "dev"


def include(path: Path) -> bool:
    rel = path.relative_to(ROOT)
    return not any(part in IGNORE for part in rel.parts)


def main() -> int:
    name, ver = package_name(), version()
    OUT.mkdir(exist_ok=True)
    zip_path = OUT / f"{name}-{ver}.zip"
    files = [path for path in ROOT.rglob("*") if path.is_file() and include(path)]
    if not files:
        print("nothing to package", file=sys.stderr)
        return 1
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(files):
            archive.write(path, f"{name}/{path.relative_to(ROOT).as_posix()}")
    digest = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    print(f"{zip_path}  {zip_path.stat().st_size} bytes  sha256={digest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

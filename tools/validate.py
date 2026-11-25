#!/usr/bin/env python3
"""Validate a WoW Forever addon without external dependencies.

Checks the TOC (Interface 16001, listed files, metadata), Lua 5.1 hazards and
the release plumbing. Exit code 1 means the addon is not shippable.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ERRORS: list[str] = []
WARNINGS: list[str] = []

LUA_HAZARDS = [
    (re.compile(r"\bgoto\s+[A-Za-z_]"), "goto is not valid in Lua 5.1"),
    (re.compile(r"(?<![<>=~])//(?![=/])"), "integer division // is not valid in Lua 5.1"),
    (re.compile(r"\bloadstring\s*\("), "loadstring() is forbidden"),
    (re.compile(r"\bRunScript\s*\("), "RunScript() is forbidden"),
    (re.compile(r"\brequire\s*\("), "require() does not exist in WoW"),
    (re.compile(r"\bio\.(open|popen|write)\b"), "io library is unavailable in WoW"),
    (re.compile(r"\bos\.(execute|exit|remove|rename)\b"), "os library is restricted in WoW"),
]


def fail(message: str) -> None:
    ERRORS.append(message)


def warn(message: str) -> None:
    WARNINGS.append(message)


def parse_toc(path: Path) -> tuple[dict[str, str], list[str]]:
    directives: dict[str, str] = {}
    files: list[str] = []
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            if line.startswith("##"):
                key, _, value = line[2:].partition(":")
                directives[key.strip()] = value.strip()
            continue
        files.append(re.sub(r"\[[^\]]*\]", "", line).strip().replace("\\", "/"))
    return directives, files


def main() -> int:
    tocs = sorted(ROOT.glob("*.toc"))
    if not tocs:
        fail("no .toc file at the addon root")
        print_report()
        return 1

    main_toc = next((toc for toc in tocs if not toc.stem.lower().endswith(("_camelot", "-camelot"))), tocs[0])
    directives, files = parse_toc(main_toc)
    interfaces = [part.strip() for part in directives.get("Interface", "").split(",") if part.strip()]
    if "16001" not in interfaces and "Interface-Camelot" not in directives:
        fail(f"{main_toc.name}: Interface is {interfaces or 'missing'}, expected 16001 (Forever)")

    for key in ("Title", "Version"):
        if not directives.get(key):
            fail(f"{main_toc.name}: missing ## {key}")
    version = directives.get("Version", "")
    if version and not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", version):
        warn(f"Version '{version}' is not semver")
    if main_toc.stem != ROOT.name:
        warn(f"TOC base name '{main_toc.stem}' does not match folder '{ROOT.name}'")

    for rel in files:
        if not rel or ".." in rel or Path(rel).is_absolute():
            fail(f"illegal file path in TOC: {rel}")
            continue
        if not (ROOT / rel).exists():
            fail(f"TOC lists missing file: {rel}")

    for path in ROOT.rglob("*.lua"):
        if ".git" in path.parts or "Libs" in path.parts:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for pattern, message in LUA_HAZARDS:
            if pattern.search(text):
                fail(f"{path.relative_to(ROOT)}: {message}")
        if "issecretvalue" not in text and re.search(r"Unit(Health|Power)\s*\(", text):
            warn(f"{path.relative_to(ROOT)}: reads combat values without an issecretvalue() guard")

    for required in (".pkgmeta", "README.md", "CHANGELOG.md", "LICENSE"):
        if not (ROOT / required).exists():
            warn(f"missing {required}")

    for workflow in (".github/workflows/ci.yml", ".github/workflows/release.yml"):
        if not (ROOT / workflow).exists():
            warn(f"missing {workflow}")

    print_report()
    return 1 if ERRORS else 0


def print_report() -> None:
    print(f"# Addon validation: {ROOT.name}\n")
    print(f"- Errors: **{len(ERRORS)}**")
    print(f"- Warnings: **{len(WARNINGS)}**\n")
    for title, items in (("Errors", ERRORS), ("Warnings", WARNINGS)):
        if items:
            print(f"## {title}\n")
            for item in items:
                print(f"- {item}")
            print()


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Rename xcresulttool attachment exports and copy the named dining shots.

`xcrun xcresulttool export attachments` writes UUID filenames plus
manifest.json. Each attachment's suggestedHumanReadableName is the
XCTAttachment name plus a unique suffix, for example
dining-service-filter_0_<uuid>.png. This script renames those files to
the suggested name, then copies any whose name contains one of the
dining screenshot tokens into the destination directory.

Price-key shots are copied when present and are not required. A
dining-service-filter shot is required, because this workflow's UI
tests always attach one.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

REQUIRED_TOKEN = "dining-service-filter"
OPTIONAL_TOKENS = ("dining-price-key",)
TOKENS = (REQUIRED_TOKEN,) + OPTIONAL_TOKENS


def iter_attachments(node):
    if isinstance(node, list):
        for item in node:
            yield from iter_attachments(item)
    elif isinstance(node, dict):
        if "exportedFileName" in node and "suggestedHumanReadableName" in node:
            yield node
        for value in node.values():
            if isinstance(value, (list, dict)):
                yield from iter_attachments(value)


def safe_name(suggested: str, fallback: str) -> str:
    name = suggested.replace("/", "_").replace("\\", "_").strip()
    if not name or name in {".", ".."}:
        return fallback
    return name


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: export_named_attachments.py STAGING DEST", file=sys.stderr)
        return 2

    staging = Path(sys.argv[1])
    dest = Path(sys.argv[2])
    manifest_path = staging / "manifest.json"
    if not manifest_path.is_file():
        print(f"manifest.json missing in {staging}", file=sys.stderr)
        return 1

    manifest = json.loads(manifest_path.read_text())
    dest.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []

    for attachment in iter_attachments(manifest):
        exported = str(attachment.get("exportedFileName") or "")
        suggested = str(attachment.get("suggestedHumanReadableName") or "")
        src = staging / exported
        if not src.is_file():
            src = staging / Path(exported).name
        if not src.is_file():
            print(f"missing exported file: {exported}")
            continue

        target = staging / safe_name(suggested, src.name)
        if target.exists() and target.resolve() != src.resolve():
            target = staging / f"{target.stem}-{src.stem}{target.suffix}"
        if target.resolve() != src.resolve():
            src.rename(target)
            print(f"renamed {exported} -> {target.name}")

        lowered = target.name.lower()
        if any(token in lowered for token in TOKENS):
            shutil.copy2(target, dest / target.name)
            copied.append(target.name)
            print(f"copied {target.name}")

    copied.sort()
    print("ARTIFACT FILES:")
    for name in copied:
        print(name)

    if not any(REQUIRED_TOKEN in name.lower() for name in copied):
        print(
            f"no attachment name contains {REQUIRED_TOKEN}",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

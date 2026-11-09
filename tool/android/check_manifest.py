#!/usr/bin/env python3
"""Check that an Android manifest declares what the release app needs.

Flutter's debug and profile manifests add the INTERNET permission for the
tool's own connection, so `flutter run` and the integration tests reach the
network even when the main manifest forgets it. A release build merges only the
main manifest, and without the permission every request fails as if the phone
were offline (v1.0.0 shipped that way). This check reads the main manifest, and
in CI the merged release manifest, and fails on anything missing.

    python3 tool/android/check_manifest.py [manifest.xml ...]
"""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID = "{http://schemas.android.com/apk/res/android}"
MAIN_MANIFEST = Path(__file__).resolve().parents[2] / "app/android/app/src/main/AndroidManifest.xml"

# Supabase (auth, data, storage, Edge Functions) needs the network.
REQUIRED_PERMISSIONS = ("android.permission.INTERNET",)


def problems(manifest: Path) -> list[str]:
    """Return what the manifest lacks; an empty list means it passes."""
    try:
        # The repository's own manifest and build outputs, not outside input.
        root = ET.parse(manifest).getroot()  # noqa: S314
    except (OSError, ET.ParseError) as error:
        return [f"{manifest}: cannot read it ({error})"]
    if root.tag != "manifest":
        return [f"{manifest}: the root element is <{root.tag}>, not <manifest>"]
    declared = {element.get(f"{ANDROID}name") for element in root.findall("uses-permission")}
    return [
        f'{manifest}: missing <uses-permission android:name="{permission}"/>'
        for permission in REQUIRED_PERMISSIONS
        if permission not in declared
    ]


def main(argv: list[str]) -> int:
    manifests = [Path(arg) for arg in argv] or [MAIN_MANIFEST]
    found = [problem for manifest in manifests for problem in problems(manifest)]
    for problem in found:
        print(problem, file=sys.stderr)
    if not found:
        print(f"Android manifest check passed ({len(manifests)} file(s)).")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

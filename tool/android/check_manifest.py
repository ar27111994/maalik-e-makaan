#!/usr/bin/env python3
"""Check that an Android manifest declares what the release app needs.

Flutter's debug and profile manifests add the INTERNET permission for the
tool's own connection, so `flutter run` and the integration tests reach the
network even when the main manifest forgets it. A release build merges only the
main manifest, and without the permission every request fails as if the phone
were offline (v1.0.0 shipped that way). The application must also name the
launcher icons that `make app-icons` writes (tool/design/build_app_icons.py),
its round variant included, or launchers that use round icons fall back to a
default. And the e-mail links (/auth/callback, /invite) must open the app on
every host of the web app: its origin and its earlier addresses in
contracts/origins.json (decision D-20), in an https App Links filter that
Android verifies (autoVerify), and on no other host. An earlier address stays
for the links already sent. This check reads the main manifest, and in CI the
merged release manifest, and fails on anything missing.

    python3 tool/android/check_manifest.py [manifest.xml ...]
"""

from __future__ import annotations

import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlsplit

ANDROID = "{http://schemas.android.com/apk/res/android}"
ROOT = Path(__file__).resolve().parents[2]
MAIN_MANIFEST = ROOT / "app/android/app/src/main/AndroidManifest.xml"
ORIGINS = ROOT / "contracts/origins.json"

# Supabase (auth, data, storage, Edge Functions) needs the network.
REQUIRED_PERMISSIONS = ("android.permission.INTERNET",)

# The launcher icons that tool/design/build_app_icons.py writes.
REQUIRED_APPLICATION_ATTRIBUTES = {
    "icon": "@mipmap/ic_launcher",
    "roundIcon": "@mipmap/ic_launcher_round",
}

# The paths the web app's e-mail links open: Supabase Auth's callback (with its
# ?code=…) and invite-member's /invite#token=….
APP_LINK_PATHS = (("pathPrefix", "/auth/callback"), ("path", "/invite"))


def app_link_hosts(origins: Path | None = None) -> set[str]:
    """The web app's hosts in contracts/origins.json: its origin and earlier addresses."""
    origins = origins or ORIGINS
    app = json.loads(origins.read_text(encoding="utf-8"))["app"]
    hosts = set()
    for url in [app["origin"], *app.get("legacy", [])]:
        parts = urlsplit(url)
        if parts.scheme != "https" or not parts.hostname or parts.path or parts.port:
            raise ValueError(f"{origins}: {url!r} is not an https origin")
        hosts.add(parts.hostname)
    return hosts


def app_link_problems(manifest: Path, root: ET.Element, hosts: set[str]) -> list[str]:
    """What the verified App Links filters lack, or have beyond the web app's hosts."""
    schemes: set[str] = set()
    found_hosts: set[str] = set()
    paths: set[tuple[str, str]] = set()
    filters = [
        intent_filter
        for intent_filter in root.iter("intent-filter")
        if intent_filter.get(f"{ANDROID}autoVerify") == "true"
    ]
    if not filters:
        return [f'{manifest}: no <intent-filter android:autoVerify="true"> for the e-mail links']
    for intent_filter in filters:
        for data in intent_filter.findall("data"):
            if data.get(f"{ANDROID}scheme"):
                schemes.add(data.get(f"{ANDROID}scheme", ""))
            if data.get(f"{ANDROID}host"):
                found_hosts.add(data.get(f"{ANDROID}host", ""))
            for kind, _ in APP_LINK_PATHS:
                if data.get(f"{ANDROID}{kind}"):
                    paths.add((kind, data.get(f"{ANDROID}{kind}", "")))
    found = []
    if schemes != {"https"}:
        found.append(f"{manifest}: the App Links filter's schemes are {sorted(schemes)}, not https")
    for host in sorted(hosts - found_hosts):
        found.append(f"{manifest}: the App Links filter lacks the web app's host {host}")
    for host in sorted(found_hosts - hosts):
        found.append(
            f"{manifest}: the App Links filter names {host}, which contracts/origins.json does"
            " not list for the web app"
        )
    for kind, path in APP_LINK_PATHS:
        if (kind, path) not in paths:
            found.append(f'{manifest}: the App Links filter lacks android:{kind}="{path}"')
    return found


def problems(manifest: Path, hosts: set[str] | None = None) -> list[str]:
    """Return what the manifest lacks; an empty list means it passes."""
    try:
        # The repository's own manifest and build outputs, not outside input.
        root = ET.parse(manifest).getroot()  # noqa: S314
    except (OSError, ET.ParseError) as error:
        return [f"{manifest}: cannot read it ({error})"]
    if root.tag != "manifest":
        return [f"{manifest}: the root element is <{root.tag}>, not <manifest>"]
    declared = {element.get(f"{ANDROID}name") for element in root.findall("uses-permission")}
    found = [
        f'{manifest}: missing <uses-permission android:name="{permission}"/>'
        for permission in REQUIRED_PERMISSIONS
        if permission not in declared
    ]
    application = root.find("application")
    if application is None:
        return [*found, f"{manifest}: no <application> element"]
    found += [
        f'{manifest}: <application> needs android:{name}="{value}"'
        for name, value in REQUIRED_APPLICATION_ATTRIBUTES.items()
        if application.get(f"{ANDROID}{name}") != value
    ]
    return found + app_link_problems(manifest, root, app_link_hosts() if hosts is None else hosts)


def main(argv: list[str]) -> int:
    manifests = [Path(arg) for arg in argv] or [MAIN_MANIFEST]
    try:
        hosts = app_link_hosts()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"{ORIGINS}: cannot read the web app's hosts ({error!r})", file=sys.stderr)
        return 1
    found = [problem for manifest in manifests for problem in problems(manifest, hosts)]
    for problem in found:
        print(problem, file=sys.stderr)
    if not found:
        print(f"Android manifest check passed ({len(manifests)} file(s)).")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

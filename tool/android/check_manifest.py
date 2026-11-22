#!/usr/bin/env python3
"""Check that an Android manifest declares what the release app needs.

Flutter's debug and profile manifests add the INTERNET permission for the
tool's own connection, so `flutter run` and the integration tests reach the
network even when the main manifest forgets it. A release build merges only the
main manifest, and without the permission every request fails as if the phone
were offline (v1.0.0 shipped that way). The application must also name the
launcher icons that `make app-icons` writes (tool/design/build_app_icons.py),
its round variant included, or launchers that use round icons fall back to a
default. Phone backups stay full (decision D-24, the owner's "Full Backup"): the
application says android:allowBackup="true", and names no backup rules
(android:fullBackupContent, android:dataExtractionRules) and no backup agent,
any of which would narrow what Google's backup or a move to a new phone keeps.
And the e-mail links (/auth/callback, /invite) must open the app on
every host of the web app: its origin and its earlier addresses in
contracts/origins.json (decision D-20), each host with both paths in one
https App Links filter that Android verifies (autoVerify) and can launch: VIEW,
DEFAULT and BROWSABLE, no port, no MIME type and nothing nested in its action, category
or data (_nested_problems, refused in every filter), under an activity (or activity
alias) that a link reaches (_component_problems: exported and enabled, in an enabled
application, and no permission a browser would need). No web link filter, verified or
not, names another host: Android 6 to 11 verify every web host of the app's
filters, all or none. An earlier address stays for the links already sent. This
check reads the main manifest, and in CI the merged release manifest, and fails
on anything missing.

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

# The launcher icons that tool/design/build_app_icons.py writes, and the phone's backup kept on
# (D-24; "true" is Android's default too, written out so that the choice is seen and checked).
REQUIRED_APPLICATION_ATTRIBUTES = {
    "icon": "@mipmap/ic_launcher",
    "roundIcon": "@mipmap/ic_launcher_round",
    "allowBackup": "true",
}

# What would narrow the phone's backup, which D-24 keeps full: a backup rules file for Android 11
# and earlier (fullBackupContent) or for Android 12 and later (dataExtractionRules), and a backup
# agent of the app's own, which decides what it backs up. With none of them, Android backs up and
# transfers everything in the app's own folders but its cache and no-backup folders.
NARROWING_BACKUP_ATTRIBUTES = ("fullBackupContent", "dataExtractionRules", "backupAgent")

# The paths the web app's e-mail links open: Supabase Auth's callback (with its
# ?code=…) and invite-member's /invite#token=….
APP_LINK_PATHS = (("pathPrefix", "/auth/callback"), ("path", "/invite"))

# What an App Links filter needs for Android to open a link with it.
LAUNCH_ACTIONS = ("android.intent.action.VIEW",)
LAUNCH_CATEGORIES = ("android.intent.category.DEFAULT", "android.intent.category.BROWSABLE")
# The components a link can start: a browser hands it to startActivity().
ACTIVITIES = ("activity", "activity-alias")
# The ways aapt2 writes a boolean attribute (ResourceUtils::ParseBool), around any spaces.
_TRUE = frozenset({"true", "True", "TRUE"})
_FALSE = frozenset({"false", "False", "FALSE"})


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


def _flag_problems(element: ET.Element, name: str, where: str, why: str) -> list[str]:
    """What keeps a boolean attribute of `element` from being "true", as aapt2 reads it: absent
    or true (in the cases aapt2 accepts, around any spaces) is nothing; false is `where` with
    `why`; anything else, a resource such as @bool/... above all, is a value this check cannot
    resolve, so it fails closed and asks for the literal."""
    raw = element.get(f"{ANDROID}{name}")
    if raw is None or raw.strip() in _TRUE:
        return []
    if raw.strip() in _FALSE:
        return [f'{where} with android:{name}="{raw}", {why}']
    return [
        f'{where} with android:{name}="{raw}", which this check cannot read: write "true" or'
        ' "false" there (a resource such as @bool/... is not resolved here)'
    ]


def _component_problems(parent: ET.Element | None, application: ET.Element | None) -> list[str]:
    """Why no link from a browser or another app reaches the component that holds the filter, as
    Android decides it (platform_frameworks_base: ParsedActivityUtils, PackageUserStateUtils,
    ActivityTaskSupervisor): it is not an activity (a link is an activity intent; a service or
    receiver never gets one), or it, or the application, is disabled, or it is not exported,
    which keeps every intent from another app out. An activity with an intent filter is exported
    unless it says not. A permission keeps a link out too: a browser holds none, so
    startActivity() fails.

    An alias is a component of its own. Android reads its enabled, exported and permission from
    the alias alone, not from its target activity: resolution checks the alias's own enabled
    state, the start checks the alias's own permission and exported, and the parser does not
    copy the target's (makeAlias: "alias.enabled = target.enabled" and the like are left out on
    purpose). So the target's attributes are not read here. The application's permission is the
    default for an activity that writes no android:permission at all; an empty one on the
    activity means none, and an alias never takes the application's ("If an alias needs the
    same permission, it must be re-declared"). Android keeps any other value, one of spaces
    included, as the permission's name."""
    if parent is None:
        tag = "no component"
    else:
        tag = f"{'an' if parent.tag[0] in 'aeiou' else 'a'} <{parent.tag}>"
    if parent is None or parent.tag not in ACTIVITIES:
        return [f"is on {tag}, which no link starts: only an <activity> or <activity-alias> is"]
    unreached = "which no link from another app reaches"
    found = [
        problem
        for name in ("exported", "enabled")
        for problem in _flag_problems(parent, name, f"is on {tag}", unreached)
    ]
    if application is not None:
        found += _flag_problems(
            application, "enabled", "is in an <application>", "which starts nothing"
        )
    # As written, not stripped: Android keeps any value that is not empty, spaces and all.
    permission = parent.get(f"{ANDROID}permission")
    where = f"is on {tag} with"
    if permission is None and parent.tag == "activity" and application is not None:
        permission = application.get(f"{ANDROID}permission")
        where = f"is on {tag} without its own permission, in an <application> with"
    if permission:
        found.append(
            f'{where} android:permission="{permission}", which a browser does not hold, so no'
            " link starts it"
        )
    return found


def _port_problems(intent_filter: ET.Element) -> list[str]:
    """A port in the filter: Android then matches only a link that names that port, and the
    e-mail links name none (not even 443, which a link without a port does not match).

    This is stricter than Android on purpose: Android pairs each port with a host, so a filter
    that also names its host without a port would still open the links, and a port on a <data>
    without a host means nothing. Any port refuses the filter, so the check fails closed rather
    than read a filter's authorities one by one."""
    ports = sorted(
        {data.get(f"{ANDROID}port", "") for data in intent_filter.findall("data")} - {""}
    )
    return [
        f'names android:port="{port}", so it matches no e-mail link (they name no port)'
        for port in ports
    ]


def _type_problems(intent_filter: ET.Element) -> list[str]:
    """A MIME type in the filter: a link from a browser or a mail app is a VIEW intent with an
    https URI and no type (Intent.resolveType() asks for one only for a content: URI), and
    IntentFilter.matchData() matches a filter with types only to an intent whose type is one of
    them, so such a filter opens no e-mail link.

    android:mimeGroup is refused as well, which is stricter than Android on purpose: the group's
    types are set by the app at run time (PackageManager.setMimeGroup), and the filter matches a
    link only while the group is empty, which this check cannot see."""
    return [
        f'names android:{name}="{value}", so it matches no e-mail link (they carry no MIME type)'
        for data in intent_filter.findall("data")
        for name in ("mimeType", "mimeGroup")
        if (value := data.get(f"{ANDROID}{name}")) is not None
    ]


def _flagged_problems(parent: ET.Element | None, intent_filter: ET.Element) -> list[str]:
    """An android:featureFlag on the filter, anything in it, or its component: where the
    platform reads it (AconfigFlags.skipCurrentElement, behind manifest flagging), Android drops
    the element when the flag is off or unknown to the device, so a <data>, or the filter itself,
    may not be there at all. The check cannot know a device's flags, so it refuses the filter."""
    elements = [*([parent] if parent is not None else []), *intent_filter.iter()]
    return [
        f'has <{element.tag} android:featureFlag="{value}">, which Android drops where that'
        " flag is off"
        for element in elements
        if (value := element.get(f"{ANDROID}featureFlag")) is not None
    ]


def _nested_problems(intent_filter: ET.Element) -> list[str]:
    """An element inside the filter's <action>, <category> or <data>. Android 11 and later read
    every element under the filter as the filter's own, however deep (ParsedIntentInfoUtils
    loops while "parser.getDepth() > depth" and its action, category and data cases skip nothing
    beneath them), while Android 10 and earlier skip what is inside (PackageParser.parseIntent:
    "XmlUtils.skipCurrentTag(parser)"). So a nested <data android:mimeType>, host or scheme
    changes what the filter opens on some phones and not on others, while this check reads only
    the filter's direct children; it refuses the filter instead. aapt2 refuses such a manifest
    too, unless manifest validation only warns."""
    return [
        f"has a <{inner.tag}> inside its <{element.tag}>, which Android 11 and later read as part"
        " of the filter and Android 10 and earlier skip: put it directly in the <intent-filter>"
        for element in intent_filter
        if element.tag in ("action", "category", "data")
        for inner in element.iter()
        if inner is not element
    ]


def _launch_lacks(intent_filter: ET.Element) -> list[str]:
    """The actions and categories Android needs to launch the activity for a link, which the
    filter lacks: a link reaches an activity as an implicit VIEW intent with BROWSABLE, and
    startActivity() adds DEFAULT to every implicit intent."""
    actions = {element.get(f"{ANDROID}name") for element in intent_filter.findall("action")}
    categories = {element.get(f"{ANDROID}name") for element in intent_filter.findall("category")}
    return [name for name in LAUNCH_ACTIONS if name not in actions] + [
        name for name in LAUNCH_CATEGORIES if name not in categories
    ]


def unverified_host_problems(manifest: Path, root: ET.Element, hosts: set[str]) -> list[str]:
    """The hosts outside the web app's that a web link filter without autoVerify names.

    On Android 6 to 11, once one filter of the app has autoVerify, the system verifies every
    host of every filter with a VIEW action and an http or https scheme, and grants App Links
    for all of them or none. A host that does not serve the web app's assetlinks.json would
    therefore stop the e-mail links opening the app on the web app's own hosts. The verified
    filters' hosts are reported by app_link_problems. An element nested in any unverified
    filter's <action>, <category> or <data> is reported as well, since Android 11 and later read
    it as the filter's own and it could add a web host."""
    found = []
    for number, intent_filter in enumerate(root.iter("intent-filter"), start=1):
        if intent_filter.get(f"{ANDROID}autoVerify") == "true":
            continue
        # Nesting can add an action, a scheme or a host on Android 11 and later, so it is
        # refused on every filter, not only on those this function reads as web filters.
        found += [
            f"{manifest}: intent filter {number} {problem}"
            for problem in _nested_problems(intent_filter)
        ]
        actions = {element.get(f"{ANDROID}name") for element in intent_filter.findall("action")}
        datas = intent_filter.findall("data")
        schemes = {data.get(f"{ANDROID}scheme") for data in datas}
        if "android.intent.action.VIEW" not in actions or not schemes & {"http", "https"}:
            continue
        named = {data.get(f"{ANDROID}host") for data in datas} - {None, ""}
        found += [
            f"{manifest}: web link filter {number} names {host}, which contracts/origins.json"
            " does not list for the web app, so Android 6 to 11 would verify no App Links host"
            for host in sorted(named - hosts)
        ]
    return found


def app_link_problems(manifest: Path, root: ET.Element, hosts: set[str]) -> list[str]:
    """What the verified App Links filters lack, or have beyond the web app's hosts.

    Android matches a link against each filter on its own: a filter opens every combination of
    its own schemes, hosts and paths, and never one filter's host with another's path. So the
    links each filter opens are worked out per filter, and only a filter that Android can launch
    (VIEW, DEFAULT, BROWSABLE, no port, no MIME type, nothing nested in its <action>,
    <category> or <data>, on an activity a link reaches), with https
    among its schemes, counts.

    Only the filter's own <data> paths count, and only the two literal ones: Android matches a
    link whose path matches any path of the filter, so other path attributes (pathPattern,
    pathAdvancedPattern, pathSuffix, another pathPrefix), scheme-specific parts (ssp,
    sspPattern and the like), more schemes and <uri-relative-filter-group> paths only widen
    what the filter opens and never stop it opening the two. android:query and
    android:fragment mean something only inside a <uri-relative-filter-group>, whose <data>
    this check does not read."""
    parents = {child: parent for parent in root.iter() for child in parent}
    application = root.find("application")
    filters = [
        intent_filter
        for intent_filter in root.iter("intent-filter")
        if intent_filter.get(f"{ANDROID}autoVerify") == "true"
    ]
    if not filters:
        return [f'{manifest}: no <intent-filter android:autoVerify="true"> for the e-mail links']
    found: list[str] = []
    opens: set[tuple[str, tuple[str, str]]] = set()
    opened_hosts: set[str] = set()
    for number, intent_filter in enumerate(filters, start=1):
        where = f"{manifest}: App Links filter {number}"
        parent = parents.get(intent_filter)
        unreachable = _component_problems(parent, application)
        unreachable += _port_problems(intent_filter)
        unreachable += _type_problems(intent_filter)
        unreachable += _flagged_problems(parent, intent_filter)
        unreachable += _nested_problems(intent_filter)
        found += [f"{where} {problem}" for problem in unreachable]
        datas = intent_filter.findall("data")
        schemes = {data.get(f"{ANDROID}scheme") for data in datas} - {None}
        named = {data.get(f"{ANDROID}host") for data in datas} - {None, ""}
        paths = {
            (kind, data.get(f"{ANDROID}{kind}", ""))
            for data in datas
            for kind, _ in APP_LINK_PATHS
            if data.get(f"{ANDROID}{kind}")
        }
        lacks = _launch_lacks(intent_filter)
        found += [f"{where} lacks {name}, so Android cannot open a link with it" for name in lacks]
        if schemes != {"https"}:
            found.append(f"{where}'s schemes are {sorted(schemes)}, not https")
        found += [
            f"{where} names {host}, which contracts/origins.json does not list for the web app"
            for host in sorted(named - hosts)
        ]
        if not lacks and not unreachable and "https" in schemes:
            opened_hosts |= named
            opens |= {(host, path) for host in named for path in paths}
    found += unverified_host_problems(manifest, root, hosts)
    found += [
        f"{manifest}: the App Links lack the web app's host {host}"
        for host in sorted(hosts - opened_hosts)
    ]
    for kind, path in APP_LINK_PATHS:
        missing = sorted(host for host in hosts & opened_hosts if (host, (kind, path)) not in opens)
        if missing:
            found.append(
                f'{manifest}: the App Links lack android:{kind}="{path}" on {", ".join(missing)}'
            )
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
    found += [
        f"{manifest}: <application> names android:{name}, which would narrow the phone's backup"
        " (decision D-24 keeps it full)"
        for name in NARROWING_BACKUP_ATTRIBUTES
        if application.get(f"{ANDROID}{name}") is not None
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

"""Tests of check_manifest.py (make test-tools)."""

import io
import json
import tempfile
import unittest
import unittest.mock
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

import check_manifest

HEADER = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
INTERNET = '<uses-permission android:name="android.permission.INTERNET"/>'
ICONS = 'android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round"'
HOSTS = {"app.example.pk", "old.example.org"}


# The <data> of an App Links filter for HOSTS: each scheme, with each host, with each path.
DATA = (
    '<data android:scheme="https"/><data android:host="app.example.pk"/>'
    '<data android:host="old.example.org"/><data android:pathPrefix="/auth/callback"/>'
    '<data android:path="/invite"/>'
)


# What Android needs to launch an activity for a link the browser or another app hands it.
LAUNCH = (
    '<action android:name="android.intent.action.VIEW"/>'
    '<category android:name="android.intent.category.DEFAULT"/>'
    '<category android:name="android.intent.category.BROWSABLE"/>'
)


def intent_filter(
    data: str = DATA, verify: str = 'android:autoVerify="true"', launch: str = LAUNCH
) -> str:
    """An App Links filter holding `data`."""
    return f"<intent-filter {verify}>{launch}{data}</intent-filter>"


def app_links(data: str = DATA, verify: str = 'android:autoVerify="true"', **kwargs) -> str:
    """An activity with an App Links filter holding `data`."""
    return (
        f'<activity android:name=".MainActivity">{intent_filter(data, verify, **kwargs)}</activity>'
    )


APPLICATION = f"<application {ICONS}>{app_links()}</application>"


class CheckManifestTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, body, name="AndroidManifest.xml", application=APPLICATION):
        path = self.dir / name
        path.write_text(f"{HEADER}{body}{application}</manifest>", encoding="utf-8")
        return path

    def run_main(self, *paths):
        out, err = io.StringIO(), io.StringIO()
        with (
            redirect_stdout(out),
            redirect_stderr(err),
            unittest.mock.patch.object(check_manifest, "app_link_hosts", return_value=HOSTS),
        ):
            code = check_manifest.main([str(path) for path in paths])
        return code, out.getvalue(), err.getvalue()

    def problems(self, path):
        return check_manifest.problems(path, HOSTS)

    def test_the_repository_main_manifest_passes(self):
        self.assertEqual(check_manifest.problems(check_manifest.MAIN_MANIFEST), [])

    def test_a_manifest_with_the_permission_passes(self):
        code, out, err = self.run_main(self.manifest(INTERNET))
        self.assertEqual(code, 0)
        self.assertIn("passed", out)
        self.assertEqual(err, "")

    def test_a_manifest_without_internet_fails(self):
        path = self.manifest('<uses-permission android:name="android.permission.CAMERA"/>')
        code, _, err = self.run_main(path)
        self.assertEqual(code, 1)
        self.assertIn("android.permission.INTERNET", err)

    def test_a_permission_named_without_the_android_namespace_does_not_count(self):
        path = self.manifest('<uses-permission name="android.permission.INTERNET"/>')
        self.assertEqual(len(self.problems(path)), 1)

    def test_every_manifest_given_is_checked(self):
        good = self.manifest(INTERNET, "good.xml")
        bad = self.manifest("", "bad.xml")
        code, _, err = self.run_main(good, bad)
        self.assertEqual(code, 1)
        self.assertIn("bad.xml", err)
        self.assertNotIn("good.xml", err)

    def test_the_application_must_name_both_launcher_icons(self):
        for application in (
            "<application/>",
            '<application android:icon="@mipmap/ic_launcher"/>',
            '<application android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/other"/>',
            '<application icon="@mipmap/ic_launcher" roundIcon="@mipmap/ic_launcher_round"/>',
        ):
            with self.subTest(application=application):
                application = application.replace("/>", f">{app_links()}</application>")
                path = self.manifest(INTERNET, application=application)
                found = self.problems(path)
                self.assertEqual(len(found), 1 if "android:icon" in application else 2)
                self.assertTrue(all("<application> needs android:" in line for line in found))

    def test_a_manifest_without_an_application_fails(self):
        path = self.manifest(INTERNET, application="")
        found = self.problems(path)
        self.assertEqual(len(found), 1)
        self.assertIn("no <application>", found[0])

    def test_an_unreadable_or_foreign_file_fails(self):
        missing = self.dir / "absent.xml"
        broken = self.dir / "broken.xml"
        broken.write_text("<manifest", encoding="utf-8")
        other = self.dir / "other.xml"
        other.write_text("<resources/>", encoding="utf-8")
        for path in (missing, broken, other):
            with self.subTest(path=path.name):
                self.assertEqual(len(self.problems(path)), 1)

    def test_the_app_links_name_exactly_the_web_apps_hosts_and_both_paths(self):
        cases = {
            "no verified filter": (app_links(verify=""), ["no <intent-filter"]),
            "an http scheme too": (
                app_links(DATA + '<data android:scheme="http"/>'),
                ["filter 1's schemes are ['http', 'https']"],
            ),
            "the earlier host missing": (
                app_links(DATA.replace("old.example.org", "app.example.pk")),
                ["lack the web app's host old.example.org"],
            ),
            "a host the file does not list": (
                app_links(DATA + '<data android:host="typo.example.pk"/>'),
                ["filter 1 names typo.example.pk, which contracts/origins.json does not list"],
            ),
            "no invitation path": (
                app_links(DATA.replace('<data android:path="/invite"/>', "")),
                ['lack android:path="/invite" on app.example.pk, old.example.org'],
            ),
            "the callback as an exact path": (
                app_links(DATA.replace("pathPrefix", "path")),
                ['lack android:pathPrefix="/auth/callback" on app.example.pk, old.example.org'],
            ),
        }
        for name, (activity, expected) in cases.items():
            with self.subTest(name):
                path = self.manifest(
                    INTERNET, application=f"<application {ICONS}>{activity}</application>"
                )
                found = self.problems(path)
                self.assertEqual(len(found), len(expected), found)
                for fragment, line in zip(expected, found, strict=True):
                    self.assertIn(fragment, line)

    def application(self, *filters: str) -> Path:
        activity = f'<activity android:name=".MainActivity">{"".join(filters)}</activity>'
        return self.manifest(INTERNET, application=f"<application {ICONS}>{activity}</application>")

    def test_hosts_and_paths_combine_within_a_filter_not_across_filters(self):
        # Android takes the cross product of a filter's schemes, hosts and paths, and never
        # mixes one filter's <data> with another's: here neither host opens both paths.
        split = self.application(
            intent_filter(
                '<data android:scheme="https"/><data android:host="app.example.pk"/>'
                '<data android:pathPrefix="/auth/callback"/>'
            ),
            intent_filter(
                '<data android:scheme="https"/><data android:host="old.example.org"/>'
                '<data android:path="/invite"/>'
            ),
        )
        found = self.problems(split)
        self.assertEqual(len(found), 2, found)
        self.assertIn('lack android:pathPrefix="/auth/callback" on old.example.org', found[0])
        self.assertIn('lack android:path="/invite" on app.example.pk', found[1])

    def test_one_filter_per_host_with_both_paths_passes(self):
        per_host = [
            intent_filter(
                f'<data android:scheme="https"/><data android:host="{host}"/>'
                '<data android:pathPrefix="/auth/callback"/><data android:path="/invite"/>'
            )
            for host in sorted(HOSTS)
        ]
        self.assertEqual(self.problems(self.application(*per_host)), [])

    def test_a_host_named_without_the_paths_lacks_them(self):
        hosts_only = self.application(
            intent_filter(
                '<data android:scheme="https"/><data android:host="app.example.pk"/>'
                '<data android:host="old.example.org"/>'
            )
        )
        found = self.problems(hosts_only)
        self.assertEqual(len(found), 2, found)
        self.assertIn('pathPrefix="/auth/callback" on app.example.pk, old.example.org', found[0])
        self.assertIn('path="/invite" on app.example.pk, old.example.org', found[1])

    def test_a_filter_without_a_scheme_opens_no_link(self):
        # Without a scheme Android ignores the filter's hosts and paths.
        schemeless = self.application(
            intent_filter(DATA.replace('<data android:scheme="https"/>', ""))
        )
        found = self.problems(schemeless)
        self.assertTrue(any("schemes are [], not https" in line for line in found), found)

    def test_a_verified_filter_must_be_launchable(self):
        view = '<action android:name="android.intent.action.VIEW"/>'
        default = '<category android:name="android.intent.category.DEFAULT"/>'
        browsable = '<category android:name="android.intent.category.BROWSABLE"/>'
        cases = {
            "no VIEW action": (LAUNCH.replace(view, ""), "android.intent.action.VIEW"),
            "no DEFAULT category": (LAUNCH.replace(default, ""), "android.intent.category.DEFAULT"),
            "no BROWSABLE category": (
                LAUNCH.replace(browsable, ""),
                "android.intent.category.BROWSABLE",
            ),
        }
        for name, (launch, missing) in cases.items():
            with self.subTest(name):
                found = self.problems(self.application(intent_filter(launch=launch)))
                self.assertTrue(found, f"{name} passed")
                self.assertIn(f"lacks {missing}", found[0])
                # Such a filter opens nothing, so its hosts count as missing too.
                self.assertTrue(any("lack the web app's host" in line for line in found))

    def test_a_launchable_filter_beside_an_unlaunchable_one_still_reports_it(self):
        broken = intent_filter(launch=LAUNCH.replace("DEFAULT", "OTHER"))
        found = self.problems(self.application(intent_filter(), broken))
        self.assertEqual(len(found), 1, found)
        self.assertIn("lacks android.intent.category.DEFAULT", found[0])

    def test_an_unverified_web_filter_may_name_only_the_web_apps_hosts(self):
        # On Android 6 to 11, once any filter has autoVerify, the system verifies every web host
        # of every filter in the app, and all or none: another host would stop the App Links.
        launch = LAUNCH.replace('<category android:name="android.intent.category.DEFAULT"/>', "")
        cases = {
            "https, VIEW and BROWSABLE": (
                intent_filter(
                    '<data android:scheme="https"/><data android:host="evil.example"/>', verify=""
                ),
                ["names evil.example"],
            ),
            "http, VIEW only": (
                intent_filter(
                    '<data android:scheme="http"/><data android:host="evil.example"/>',
                    verify="",
                    launch='<action android:name="android.intent.action.VIEW"/>',
                ),
                ["names evil.example"],
            ),
            "a listed host": (
                intent_filter(
                    '<data android:scheme="https"/><data android:host="app.example.pk"/>',
                    verify="",
                    launch=launch,
                ),
                [],
            ),
            "a custom scheme": (
                intent_filter(
                    '<data android:scheme="pk.example.app"/><data android:host="evil.example"/>',
                    verify="",
                ),
                [],
            ),
            "no VIEW action": (
                intent_filter(
                    '<data android:scheme="https"/><data android:host="evil.example"/>',
                    verify="",
                    launch=launch.replace("action.VIEW", "action.SEND"),
                ),
                [],
            ),
        }
        for name, (extra, expected) in cases.items():
            with self.subTest(name):
                found = self.problems(self.application(intent_filter(), extra))
                self.assertEqual(len(found), len(expected), found)
                for fragment, line in zip(expected, found, strict=True):
                    self.assertIn(fragment, line)
                    self.assertIn("web link filter 2", line)

    def component(self, element: str, application: str = f"<application {ICONS}>") -> Path:
        """A manifest whose one App Links filter sits in `element` (an opening tag)."""
        tag = element[1:].split(" ", 1)[0].rstrip(">")
        return self.manifest(
            INTERNET, application=f"{application}{element}{intent_filter()}</{tag}></application>"
        )

    def test_a_filter_counts_only_on_an_activity_a_link_reaches(self):
        # A link reaches only an activity (or an activity alias) that another app may start.
        missing = ["lack the web app's host app.example.pk", "host old.example.org"]
        cases = {
            "an activity that is not exported": (
                '<activity android:name=".A" android:exported="false">',
                ['filter 1 is on an <activity> with android:exported="false"', *missing],
            ),
            "a disabled activity": (
                '<activity android:name=".A" android:enabled="false">',
                ['filter 1 is on an <activity> with android:enabled="false"', *missing],
            ),
            "an alias that is neither": (
                '<activity-alias android:name=".B" android:targetActivity=".A"'
                ' android:exported="false" android:enabled="false">',
                [
                    'filter 1 is on an <activity-alias> with android:exported="false"',
                    'filter 1 is on an <activity-alias> with android:enabled="false"',
                    *missing,
                ],
            ),
            "a service": (
                '<service android:name=".S" android:exported="true">',
                ["filter 1 is on a <service>, which no link starts", *missing],
            ),
            "a receiver": (
                '<receiver android:name=".R">',
                ["filter 1 is on a <receiver>, which no link starts", *missing],
            ),
        }
        for name, (element, expected) in cases.items():
            with self.subTest(name):
                found = self.problems(self.component(element))
                self.assertEqual(len(found), len(expected), found)
                for fragment, line in zip(expected, found, strict=True):
                    self.assertIn(fragment, line)

    def test_an_alias_does_not_need_its_target_enabled(self):
        # Android reads an alias's enabled from the alias alone (makeAlias copies no enabled from
        # the target, and resolution checks the alias's own state), so a link starts a disabled
        # activity through an enabled alias.
        alias = '<activity-alias android:name=".B" android:targetActivity="{target}">'
        cases = {
            # The target named as the alias names it, with the package in front, or without it.
            "a dot name": ('<activity android:name=".A" android:enabled="false"/>', ".A", ""),
            "a full name": (
                '<activity android:name="pk.example.A" android:enabled="false"/>',
                ".A",
                ' package="pk.example"',
            ),
            "a short name": (
                '<activity android:name="A" android:enabled="false"/>',
                ".A",
                ' package="pk.example"',
            ),
            "a target that is not exported either": (
                '<activity android:name=".A" android:enabled="false" android:exported="false"/>',
                ".A",
                "",
            ),
        }
        for name, (target, named, package) in cases.items():
            with self.subTest(name):
                path = self.dir / "AndroidManifest.xml"
                body = (
                    f"{HEADER.replace('>', package + '>', 1)}{INTERNET}<application {ICONS}>"
                    f"{target}{alias.format(target=named)}{intent_filter()}</activity-alias>"
                    "</application></manifest>"
                )
                path.write_text(body, encoding="utf-8")
                self.assertEqual(self.problems(path), [])
        # The alias's own enabled, and the application's, still count.
        for element, application, expected in (
            (
                '<activity-alias android:name=".B" android:targetActivity=".A"'
                ' android:enabled="false">',
                f"<application {ICONS}>",
                'is on an <activity-alias> with android:enabled="false"',
            ),
            (
                '<activity-alias android:name=".B" android:targetActivity=".A">',
                f'<application {ICONS} android:enabled="false">',
                'is in an <application> with android:enabled="false"',
            ),
        ):
            with self.subTest(expected):
                path = self.component(element, application + '<activity android:name=".A"/>')
                found = self.problems(path)
                self.assertEqual(len(found), 3, found)
                self.assertIn(expected, found[0])

    def test_a_permission_keeps_every_link_out(self):
        permission = 'android:permission="pk.example.PRIVATE"'
        target = '<activity android:name=".A"/>'
        cases = {
            "on the activity": (
                f'<activity android:name=".A" {permission}>',
                f"<application {ICONS}>",
                "is on an <activity> with",
            ),
            "on the alias": (
                f'<activity-alias android:name=".B" android:targetActivity=".A" {permission}>',
                f"<application {ICONS}>{target}",
                "is on an <activity-alias> with",
            ),
            "on the application, for an activity that sets none": (
                '<activity android:name=".A">',
                f"<application {ICONS} {permission}>",
                "is on an <activity> without its own permission, in an <application> with",
            ),
        }
        for name, (element, application, where) in cases.items():
            with self.subTest(name):
                found = self.problems(self.component(element, application))
                self.assertEqual(len(found), 3, found)
                self.assertIn(
                    f'filter 1 {where} android:permission="pk.example.PRIVATE", which a browser'
                    " does not hold",
                    found[0],
                )
        # Android keeps any value that is not empty as the permission's name, spaces and all,
        # and a browser holds no permission of that name either; an empty value is none.
        for value in ("   ", " pk.example.PRIVATE "):
            with self.subTest(value=value):
                element = f'<activity android:name=".A" android:permission="{value}">'
                found = self.problems(self.component(element))
                self.assertEqual(len(found), 3, found)
                self.assertIn(f'with android:permission="{value}", which a browser', found[0])
        found = self.problems(self.component('<activity android:name=".A" android:permission="">'))
        self.assertEqual(found, [])

    def test_only_the_permission_android_applies_counts(self):
        # An alias's permission is its own alone: neither its target's nor the application's
        # applies ("If an alias needs the same permission, it must be re-declared"). An activity
        # takes the application's only when it writes none; an empty one means none.
        permission = 'android:permission="pk.example.PRIVATE"'
        alias = '<activity-alias android:name=".B" android:targetActivity=".A"{extra}>'
        cases = {
            "on the alias's target": (
                alias.format(extra=""),
                f'<application {ICONS}><activity android:name=".A" {permission}/>',
            ),
            "on the application, for an alias": (
                alias.format(extra=""),
                f'<application {ICONS} {permission}><activity android:name=".A"/>',
            ),
            "on the target, with an empty one on the alias": (
                alias.format(extra=' android:permission=""'),
                f'<application {ICONS}><activity android:name=".A" {permission}/>',
            ),
            "on the application, with an empty one on the activity": (
                '<activity android:name=".A" android:permission="">',
                f"<application {ICONS} {permission}>",
            ),
        }
        for name, (element, application) in cases.items():
            with self.subTest(name):
                self.assertEqual(self.problems(self.component(element, application)), [])

    def test_exported_and_enabled_read_as_aapt2_reads_them(self):
        missing = ["lack the web app's host app.example.pk", "host old.example.org"]
        for name in ("exported", "enabled"):
            for value in ("FALSE", "False", " false "):
                with self.subTest(name=name, value=value):
                    element = f'<activity android:name=".A" android:{name}="{value}">'
                    found = self.problems(self.component(element))
                    self.assertEqual(len(found), 3, found)
                    self.assertIn(f'with android:{name}="{value}", which no link', found[0])
            for value in ("TRUE", "True", " true"):
                with self.subTest(name=name, value=value):
                    element = f'<activity android:name=".A" android:{name}="{value}">'
                    self.assertEqual(self.problems(self.component(element)), [])
            # A value this check cannot resolve fails closed, and says to write the literal.
            for value in ("@bool/links", "fAlSe", "yes", ""):
                with self.subTest(name=name, value=value):
                    element = f'<activity android:name=".A" android:{name}="{value}">'
                    found = self.problems(self.component(element))
                    self.assertEqual(len(found), 3, found)
                    self.assertIn(
                        f'with android:{name}="{value}", which this check cannot read: write'
                        ' "true" or "false" there',
                        found[0],
                    )
                    for fragment, line in zip(missing, found[1:], strict=True):
                        self.assertIn(fragment, line)
        # The application's enabled, too.
        for value, expected in (("FALSE", "which starts nothing"), ("@bool/on", "cannot read")):
            with self.subTest(application=value):
                application = f'<application {ICONS} android:enabled="{value}">'
                found = self.problems(self.component('<activity android:name=".A">', application))
                self.assertEqual(len(found), 3, found)
                self.assertIn(expected, found[0])

    def test_a_disabled_application_starts_nothing(self):
        found = self.problems(
            self.component(
                '<activity android:name=".A">',
                f'<application {ICONS} android:enabled="false">',
            )
        )
        self.assertEqual(len(found), 3, found)
        self.assertIn('is in an <application> with android:enabled="false"', found[0])

    def test_a_filter_outside_any_component_opens_nothing(self):
        path = self.manifest(
            INTERNET, application=f"<application {ICONS}>{intent_filter()}</application>"
        )
        found = self.problems(path)
        self.assertEqual(len(found), 3, found)
        self.assertIn("filter 1 is on an <application>, which no link starts", found[0])

    def test_activities_and_aliases_that_links_reach_pass(self):
        for element in (
            '<activity android:name=".A">',
            '<activity android:name=".A" android:exported="true" android:enabled="true">',
            '<activity-alias android:name=".B" android:targetActivity=".A">',
            '<activity-alias android:name=".B" android:targetActivity=".A" android:exported="true">',
        ):
            with self.subTest(element):
                self.assertEqual(self.problems(self.component(element)), [])

    def test_a_port_keeps_a_filter_from_the_e_mail_links(self):
        # With a port, Android matches only links naming that port; the e-mail links name none.
        for port in ("8443", "443"):
            with self.subTest(port=port):
                data = DATA + f'<data android:port="{port}"/>'
                found = self.problems(self.application(intent_filter(data)))
                self.assertEqual(len(found), 3, found)
                self.assertIn(f'filter 1 names android:port="{port}"', found[0])
                self.assertIn("lack the web app's host app.example.pk", found[1])
        # Beside a filter without a port, it is still reported.
        ported = intent_filter(DATA + '<data android:port="8443"/>')
        found = self.problems(self.application(intent_filter(), ported))
        self.assertEqual(len(found), 1, found)
        self.assertIn('filter 2 names android:port="8443"', found[0])

    def test_a_mime_type_keeps_a_filter_from_the_e_mail_links(self):
        # A link from a browser or a mail app carries an https URI and no MIME type, and Android
        # matches a filter that names types only to an intent of one of those types. A MIME group
        # is filled at run time, so it is refused too.
        for name, value in (
            ("mimeType", "text/html"),
            ("mimeType", "*/*"),
            ("mimeGroup", "links"),
        ):
            with self.subTest(name=name, value=value):
                data = DATA + f'<data android:{name}="{value}"/>'
                found = self.problems(self.application(intent_filter(data)))
                self.assertEqual(len(found), 3, found)
                self.assertIn(
                    f'filter 1 names android:{name}="{value}", so it matches no', found[0]
                )
                self.assertIn("lack the web app's host app.example.pk", found[1])
        # On the same <data> as the host, too, and beside a filter without one it is reported.
        typed = intent_filter(
            DATA.replace(
                '<data android:host="app.example.pk"/>',
                '<data android:host="app.example.pk" android:mimeType="text/html"/>',
            )
        )
        found = self.problems(self.application(intent_filter(), typed))
        self.assertEqual(len(found), 1, found)
        self.assertIn('filter 2 names android:mimeType="text/html"', found[0])

    def test_an_element_nested_in_an_action_category_or_data_refuses_the_filter(self):
        # Android 11 and later read every element under the filter as its own, however deep, and
        # Android 10 and earlier skip what is inside an <action>, <category> or <data>: a MIME
        # type nested in the VIEW action would open no link on newer phones.
        view = '<action android:name="android.intent.action.VIEW"/>'
        browsable = '<category android:name="android.intent.category.BROWSABLE"/>'
        typed = '<data android:mimeType="text/html"/>'
        for name, (launch, data, inner, outer) in {
            "a MIME type in the VIEW action": (
                LAUNCH.replace(view, view.replace("/>", f">{typed}</action>")),
                DATA,
                "data",
                "action",
            ),
            "a host and port in a category": (
                LAUNCH.replace(
                    browsable,
                    browsable.replace(
                        "/>", '><data android:host="x.example" android:port="1"/></category>'
                    ),
                ),
                DATA,
                "data",
                "category",
            ),
            "a content scheme in a data": (
                LAUNCH,
                DATA.replace(
                    '<data android:path="/invite"/>',
                    '<data android:path="/invite"><data android:scheme="content"/></data>',
                ),
                "data",
                "data",
            ),
            "an action in a data, which only widens the filter": (
                LAUNCH,
                DATA.replace(
                    '<data android:path="/invite"/>',
                    f'<data android:path="/invite">{view}</data>',
                ),
                "action",
                "data",
            ),
        }.items():
            with self.subTest(name):
                found = self.problems(self.application(intent_filter(data, launch=launch)))
                self.assertEqual(len(found), 3, found)
                self.assertIn(
                    f"filter 1 has a <{inner}> inside its <{outer}>, which Android 11", found[0]
                )
                self.assertIn("lack the web app's host app.example.pk", found[1])
        # An unverified filter, web or not, is refused too: on Android 11 and later its nested
        # <data> could add a host that Android 6 to 11 would then have to verify.
        for name, launch in {
            "a web filter": LAUNCH,
            "a launcher filter": '<action android:name="android.intent.action.MAIN"/>'
            '<category android:name="android.intent.category.LAUNCHER"/>',
        }.items():
            with self.subTest(name):
                nested = launch.replace(
                    "/>", '><data android:scheme="https" android:host="x.example"/></action>', 1
                )
                extra = intent_filter('<data android:scheme="https"/>', verify="", launch=nested)
                found = self.problems(self.application(intent_filter(), extra))
                self.assertEqual(len(found), 1, found)
                self.assertIn("intent filter 2 has a <data> inside its <action>", found[0])

    def test_other_data_attributes_do_not_stop_the_two_paths_counting(self):
        # Android opens a link whose path matches any path of the filter, so more paths, more
        # schemes' specific parts and relative-reference groups only widen the filter, and
        # android:query and android:fragment mean nothing outside such a group.
        for extra in (
            '<data android:pathPattern="/x.*"/>',
            '<data android:pathAdvancedPattern="/x[0-9]+"/>',
            '<data android:pathSuffix="/y"/>',
            '<data android:pathPrefix="/other"/>',
            '<data android:ssp="//app.example.pk/z"/>',
            '<data android:sspPattern="//.*"/>',
            '<data android:query="a=1" android:fragment="f"/>',
            '<uri-relative-filter-group android:allow="false"><data android:path="/invite"/>'
            "</uri-relative-filter-group>",
        ):
            with self.subTest(extra):
                self.assertEqual(self.problems(self.application(intent_filter(DATA + extra))), [])
        # A path only inside a group is not counted: this check reads the filter's own <data>.
        grouped = DATA.replace('<data android:path="/invite"/>', "") + (
            '<uri-relative-filter-group><data android:path="/invite"/></uri-relative-filter-group>'
        )
        found = self.problems(self.application(intent_filter(grouped)))
        self.assertEqual(len(found), 1, found)
        self.assertIn('lack android:path="/invite"', found[0])

    def test_a_feature_flag_keeps_a_filter_from_counting(self):
        # Android drops an element whose feature flag is off on the device, so the check cannot
        # count on a flagged filter, <data> or component.
        flag = 'android:featureFlag="pk.example.links"'
        for name, (element, data) in {
            "on the activity": (f'<activity android:name=".A" {flag}>', DATA),
            "on a <data>": (
                '<activity android:name=".A">',
                DATA.replace(
                    '<data android:path="/invite"/>', f'<data android:path="/invite" {flag}/>'
                ),
            ),
        }.items():
            with self.subTest(name):
                activity = f"{element}{intent_filter(data)}</activity>"
                path = self.manifest(
                    INTERNET, application=f"<application {ICONS}>{activity}</application>"
                )
                found = self.problems(path)
                self.assertEqual(len(found), 3, found)
                self.assertIn(
                    'android:featureFlag="pk.example.links">, which Android drops', found[0]
                )
        flagged = intent_filter(verify=f'android:autoVerify="true" {flag}')
        found = self.problems(self.application(flagged))
        self.assertEqual(len(found), 3, found)
        self.assertIn("has <intent-filter android:featureFlag=", found[0])

    def test_an_unreadable_origins_file_fails(self):
        err = io.StringIO()
        with (
            redirect_stderr(err),
            unittest.mock.patch.object(check_manifest, "ORIGINS", self.dir / "absent.json"),
        ):
            self.assertEqual(check_manifest.main([]), 1)
        self.assertIn("cannot read the web app's hosts", err.getvalue())

    def test_the_hosts_come_from_contracts_origins_json(self):
        origins = json.loads(check_manifest.ORIGINS.read_text(encoding="utf-8"))["app"]
        expected = {url.removeprefix("https://") for url in [origins["origin"], *origins["legacy"]]}
        self.assertEqual(check_manifest.app_link_hosts(), expected)
        for bad in ("http://a.example", "https://a.example/path", "https://a.example:8443"):
            with self.subTest(bad):
                file = self.dir / "origins.json"
                file.write_text(json.dumps({"app": {"origin": bad}}), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "is not an https origin"):
                    check_manifest.app_link_hosts(file)


if __name__ == "__main__":
    unittest.main()

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

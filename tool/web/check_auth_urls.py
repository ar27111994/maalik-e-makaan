#!/usr/bin/env python3
"""Check, before a release's builds or a deploy, that Supabase Auth sends the e-mail links of
every build where that build can finish them.

    python3 tool/web/check_auth_urls.py --project-ref REF [--origins FILE] [--plist FILE]
    python3 tool/web/check_auth_urls.py AUTH_JSON [--origins FILE] [--plist FILE]

With --project-ref it reads the hosted project's settings itself, with the Management API
(GET /v1/projects/{ref}/config/auth) and the access token in SUPABASE_ACCESS_TOKEN, and keeps
only `site_url` and `uri_allow_list` (the comma-separated redirect URLs): the rest of the answer
can hold secrets, and is neither printed nor written anywhere. The Release workflow runs it
before its builds and the Deploy workflow's supabase job before it deploys. A token that may not
read Auth's settings (401 or 403) only warns, and what the check gates goes ahead: the owner
compares Authentication, URL Configuration with docs/operations.md, Domains, by hand. No answer,
a 5xx, 408 or 429 is tried again, six tries in all (after the seconds of a Retry-After header, at
most a minute, or else five seconds; check_live.answer), since the Release workflow's preflight
job and the Deploy workflow's supabase job call the Management API at the same moment. Any other
answer, or one of those on the last try, fails. AUTH_JSON is a file holding those two fields, for
a check by hand.

A build asks Auth to send its e-mail links (confirmation, password reset, e-mail change) to
`APP_URL/auth/callback` (the web app and Android), or, on iOS, to the same address under the
app's URL scheme (CFBundleURLSchemes in app/ios/Runner/Info.plist). Auth uses that address only
if it allows it, and otherwise the Site URL, where no app finishes the sign-in. Auth allows an
address (supabase/auth, utilities.IsRedirectURLValid) when its scheme, host and port are the Site
URL's, or when it matches an entry of the list: a glob in which `*` stands for any characters but
`.` and `/`, `**` for any characters, `?` for one character but those, `[...]` for one of a
class (`[!...]` for one not in it) and `{a,b}` for either.

- The web app's origin (app.origin in contracts/origins.json): its https callback and the iOS
  form of it must be allowed, or the deploy stops, since this release's builds send them.
- Each earlier address (app.legacy): builds from before the move send its callbacks. While the
  Site URL is still on that host, its https callback is allowed by the Site URL alone, which
  the move changes (docs/operations.md, Domains, step 8), so both callbacks must be listed, or
  the deploy stops. Once the Site URL is elsewhere, an earlier address's callback that is not
  allowed only warns: the owner drops them once those builds are out of use.
"""

from __future__ import annotations

import argparse
import json
import os
import plistlib
import re
import sys
import time
import urllib.error
import urllib.request
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).parent))
from check_live import Answer, OriginsError, UnreachableError, answer, read_origins

REPO = Path(__file__).resolve().parents[2]
PLIST = REPO / "app/ios/Runner/Info.plist"
CALLBACK = "/auth/callback"
HELP = "docs/operations.md, Domains"
_SEPARATORS = "./"
_LOOPBACK = {"localhost", "127.0.0.1", "::1"}
MANAGEMENT_API = "https://api.supabase.com"
ACCESS_ENV = "SUPABASE_ACCESS_TOKEN"
# A Supabase project's reference: twenty lower-case letters.
_PROJECT_REF = re.compile(r"[a-z]{20}")
# Auth's settings are a few kilobytes; nothing beyond this is read.
BODY_LIMIT = 1 << 20
TIMEOUT_SECONDS = 30.0


class AuthCheckError(Exception):
    """An input cannot be read."""


def glob_regex(pattern: str) -> re.Pattern[str]:
    """The regular expression of an allow-list entry, as github.com/gobwas/glob (v0.2.3, the
    version Auth uses) compiles it with the separators `.` and `/`."""
    body, _ = _glob(pattern, 0, top=True)
    return re.compile(body, re.DOTALL)


def _glob(pattern: str, i: int, top: bool) -> tuple[str, int]:
    """(regex, index) of `pattern` from `i` up to the end, or inside {...} up to `,` or `}`."""
    out: list[str] = []
    others = re.escape(_SEPARATORS)
    while i < len(pattern):
        char = pattern[i]
        if char == "\\":
            if i + 1 == len(pattern):
                raise AuthCheckError(f"{pattern!r}: a trailing backslash")
            out.append(re.escape(pattern[i + 1]))
            i += 2
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif char == "*":
            out.append(f"[^{others}]*")
            i += 1
        elif char == "?":
            out.append(f"[^{others}]")
            i += 1
        elif char == "[":
            end = pattern.find("]", i + 1)
            if end == -1:
                raise AuthCheckError(f"{pattern!r}: an unclosed [")
            inside = pattern[i + 1 : end]
            negated = inside.startswith("!")
            inside = inside[1:] if negated else inside
            if not inside:
                raise AuthCheckError(f"{pattern!r}: an empty []")
            escaped = "".join(
                part if part == "-" else re.escape(part) for part in re.split(r"(-)", inside)
            )
            out.append(f"[{'^' if negated else ''}{escaped}]")
            i = end + 1
        elif char == "{":
            choices = []
            i += 1
            while True:
                choice, i = _glob(pattern, i, top=False)
                choices.append(choice)
                if i == len(pattern):
                    raise AuthCheckError(f"{pattern!r}: an unclosed {{")
                i += 1
                if pattern[i - 1] == "}":
                    break
            out.append(f"(?:{'|'.join(choices)})")
        elif char in ",}" and not top:
            return "".join(out), i
        else:
            out.append(re.escape(char))
            i += 1
    return "".join(out), i


@dataclass(frozen=True)
class AuthUrls:
    """Auth's Site URL and redirect URLs."""

    site_url: str
    allow_list: tuple[str, ...]

    def by_site_url(self, url: str) -> bool:
        """Allowed for being on the Site URL: the same scheme, host and port (any port for a
        loopback host)."""
        site, ref = urlsplit(self.site_url), urlsplit(url)
        try:
            same_port = site.port == ref.port or ref.hostname in _LOOPBACK
        except ValueError:
            return False
        return bool(
            site.hostname
            and site.hostname == ref.hostname
            and site.scheme == ref.scheme
            and same_port
        )

    def listed(self, url: str) -> bool:
        """Allowed by an entry of the redirect URLs."""
        return any(glob_regex(entry).fullmatch(url) for entry in self.allow_list)


def auth_urls(data: object, source: str) -> AuthUrls:
    """The Site URL and redirect URLs of Auth's settings `data`, read from `source`."""
    if not isinstance(data, dict) or "site_url" not in data:
        raise AuthCheckError(f"{source}: cannot read Auth's site_url")
    site_url, allow = data["site_url"] or "", data.get("uri_allow_list") or ""
    if not isinstance(site_url, str) or not isinstance(allow, str):
        raise AuthCheckError(f"{source}: site_url and uri_allow_list must be strings")
    entries = tuple(entry.strip() for entry in allow.split(",") if entry.strip())
    for entry in entries:
        glob_regex(entry)
    return AuthUrls(site_url, entries)


def read_auth(path: Path) -> AuthUrls:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise AuthCheckError(f"{path}: cannot read Auth's site_url ({error!r})") from error
    return auth_urls(data, str(path))


class TokenCannotReadError(Exception):
    """The access token may not read Auth's settings (401 or 403)."""


def fetch_with_token(token: str) -> Callable[[str], Answer]:
    """A GET for check_live.answer() that sends `token` and follows no redirect."""

    def get(url: str) -> Answer:
        # The URL is MANAGEMENT_API's, with a project reference checked against _PROJECT_REF.
        request = urllib.request.Request(  # noqa: S310
            url,
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/json",
                "User-Agent": "maalik-e-makaan-deploy-check",
            },
        )
        opener = urllib.request.build_opener(_NoRedirect)
        try:
            with opener.open(request, timeout=TIMEOUT_SECONDS) as response:
                return Answer(
                    response.status,
                    body=response.read(BODY_LIMIT),
                    retry_after=response.headers.get("Retry-After", ""),
                )
        except urllib.error.HTTPError as error:
            with error:
                return Answer(
                    error.code,
                    body=error.read(BODY_LIMIT),
                    retry_after=error.headers.get("Retry-After", ""),
                )
        except (urllib.error.URLError, OSError) as error:
            raise UnreachableError(str(getattr(error, "reason", error))) from error

    return get


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Hands a redirect back as an answer, so the token never goes to another address."""

    def redirect_request(self, *args, **kwargs):
        return None


def fetch_auth(
    project_ref: str,
    token: str,
    get: Callable[[str], Answer] | None = None,
    sleep: Callable[[float], None] = time.sleep,
) -> AuthUrls:
    """Auth's Site URL and redirect URLs, read with the Management API; raises
    TokenCannotReadError on 401 or 403, and AuthCheckError on any other failure."""
    if not _PROJECT_REF.fullmatch(project_ref):
        raise AuthCheckError(f"{project_ref!r} is not a Supabase project reference")
    if not token:
        raise AuthCheckError(f"{ACCESS_ENV} is not set")
    url = f"{MANAGEMENT_API}/v1/projects/{project_ref}/config/auth"
    try:
        got = answer(url, get or fetch_with_token(token), sleep)
    except UnreachableError as error:
        raise AuthCheckError(
            f"Auth's settings could not be read ({error}); run this again"
        ) from error
    if got.status in (401, 403):
        raise TokenCannotReadError(got.status)
    if got.status != 200:
        raise AuthCheckError(
            f"Auth's settings could not be read (HTTP {got.status}); run this again"
        )
    try:
        data = json.loads(got.body)
    except (ValueError, UnicodeDecodeError) as error:
        raise AuthCheckError("the Management API's answer is not JSON") from error
    # Only these two fields are kept: the rest of the answer can hold secrets.
    return auth_urls(data, "the Management API's answer")


def read_schemes(path: Path = PLIST) -> tuple[str, ...]:
    """The URL schemes the iOS app registers."""
    try:
        with path.open("rb") as file:
            types = plistlib.load(file).get("CFBundleURLTypes", [])
        schemes = tuple(scheme for kind in types for scheme in kind.get("CFBundleURLSchemes", []))
    except (OSError, plistlib.InvalidFileException, AttributeError, TypeError) as error:
        raise AuthCheckError(f"{path}: cannot read CFBundleURLTypes ({error!r})") from error
    if not schemes or not all(isinstance(scheme, str) and scheme for scheme in schemes):
        raise AuthCheckError(f"{path}: the app registers no URL scheme")
    return schemes


def callbacks(origin: str, schemes: tuple[str, ...]) -> list[str]:
    """The addresses a build on `origin` sends: the https callback, then its iOS forms."""
    host = origin.removeprefix("https://")
    return [f"{origin}{CALLBACK}", *(f"{scheme}://{host}{CALLBACK}" for scheme in schemes)]


def check(
    auth: AuthUrls, app: str, legacy: tuple[str, ...], schemes: tuple[str, ...]
) -> tuple[list[str], list[str]]:
    """(errors, warnings) for Auth's settings against the web app's origins."""
    errors: list[str] = []
    warnings: list[str] = []
    for url in callbacks(app, schemes):
        if auth.listed(url):
            print(f"{url}: allowed (redirect URLs)")
        elif auth.by_site_url(url):
            print(f"{url}: allowed (the Site URL's host)")
        else:
            errors.append(
                f"Auth does not allow {url}, which this release's builds send: add it to the"
                f" redirect URLs (Authentication, URL Configuration; {HELP}, step 4), or every"
                f" e-mail link goes to the Site URL, {auth.site_url or '(none)'}"
            )
    for old in legacy:
        for url in callbacks(old, schemes):
            if auth.listed(url):
                print(f"{url}: allowed (redirect URLs)")
            elif auth.by_site_url(url):
                errors.append(
                    f"Auth allows {url} only because the Site URL is on its host; list it in the"
                    f" redirect URLs before the Site URL moves ({HELP}, steps 4 and 8), or the"
                    " e-mail links of builds from before the move go to the new Site URL"
                )
            elif urlsplit(auth.site_url).hostname == urlsplit(url).hostname:
                errors.append(
                    f"Auth does not allow {url}, which builds from before the move send: add"
                    f" it to the redirect URLs ({HELP}, step 4)"
                )
            else:
                warnings.append(
                    f"Auth does not allow {url}: builds from before the move get their e-mail"
                    " links at the Site URL instead. Fine once those builds are out of use"
                    f" ({HELP})"
                )
    return errors, warnings


def main(
    argv: list[str] | None = None,
    environ: Mapping[str, str] = os.environ,
    get: Callable[[str], Answer] | None = None,
    sleep: Callable[[float], None] = time.sleep,
) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("auth", type=Path, nargs="?", help="site_url and uri_allow_list, as JSON")
    source.add_argument(
        "--project-ref",
        help=f"read the hosted project's settings with the Management API ({ACCESS_ENV})",
    )
    parser.add_argument("--origins", type=Path, help="default: contracts/origins.json")
    parser.add_argument("--plist", type=Path, default=PLIST, help="the iOS app's Info.plist")
    args = parser.parse_args(argv)
    try:
        origins = read_origins(args.origins)
        schemes = read_schemes(args.plist)
        if args.project_ref is None:
            auth = read_auth(args.auth)
        else:
            auth = fetch_auth(args.project_ref, environ.get(ACCESS_ENV, ""), get, sleep)
    except TokenCannotReadError as status:
        print(
            f"::warning::The access token may not read Auth's settings (HTTP {status}), so the"
            " redirect URLs are not checked and what this check gates goes ahead: compare"
            f" Authentication, URL Configuration with {HELP}, step 4, by hand"
        )
        return 0
    except (AuthCheckError, OriginsError) as error:
        print(f"::error::{error}")
        return 2
    errors, warnings = check(auth, origins.app, origins.app_legacy, schemes)
    for warning in warnings:
        print(f"::warning::{warning}")
    for error in errors:
        print(f"::error::{error}")
    if errors:
        print(
            f"{len(errors)} e-mail link address(es) not allowed; nothing that sends them is built"
            " or deployed"
        )
        return 1
    print("Auth allows the e-mail links of this release's builds")
    return 0


if __name__ == "__main__":
    sys.exit(main())

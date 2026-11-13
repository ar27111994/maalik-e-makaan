#!/usr/bin/env python3
"""Check, before a release's builds or a production deploy, that the addresses they send people
to answer over HTTPS.

    python3 tool/web/check_live.py app   # before the release's builds and the web app's deploy
    python3 tool/web/check_live.py site  # before the website's deploy

The addresses are those of contracts/origins.json (decision D-20; --origins names another file).
A deploy makes each earlier address redirect to its origin, and every build, page and e-mail
link then names the origin, so an origin that does not answer would take the old address and
the new one offline together. An Android build lists both hosts in its App Links, and Android 6
to 11 verify all of an app's hosts or none, so a host without its assetlinks.json would also
cost the earlier host's links. Each check therefore runs before anything is built or deployed,
and fails closed:

- app: the web app's origin answers /.well-known/assetlinks.json with 200 and a JSON list of
  statements, over HTTPS with a valid certificate. Every deployment of the web app serves the
  file, the one from before a move included, so this holds as soon as the DNS records and the
  certificate are in place (docs/operations.md, Domains, steps 2 and 3).
- site: the site's origin answers / with 200, and each alias (www) answers / with 308 to it.
  Then the web app the site links to: the app check, and each earlier address of the web app
  answers / with 308 to the web app's origin, which only a deployment that carries the move
  does (tool/web/package_vercel.py). Before that, the web app at the origin is the build from
  before the move, whose e-mail links name the earlier address, where the sign-in verifier
  stored at the origin does not exist.

Redirects are not followed. A request that fails (DNS, connection, certificate, timeout) or
answers 5xx is tried again, five seconds apart, six tries in all.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

ORIGINS = Path(__file__).resolve().parents[2] / "contracts/origins.json"
ASSETLINKS = "/.well-known/assetlinks.json"
TRIES = 6
PAUSE_SECONDS = 5.0
TIMEOUT_SECONDS = 30.0
# Enough of a body for assetlinks.json; nothing else is read.
BODY_LIMIT = 1 << 20
HELP = "docs/operations.md, Domains"
DNS = f"point its DNS at Vercel and wait for the certificate ({HELP}, steps 2 and 3)"

_ORIGIN = re.compile(r"https://(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}")


class OriginsError(Exception):
    """contracts/origins.json cannot be read, or holds something that is not an origin."""


class UnreachableError(Exception):
    """A request got no HTTP answer: DNS, connection, certificate or timeout."""


@dataclass(frozen=True)
class Origins:
    """The addresses of contracts/origins.json that the checks use."""

    site: str
    site_aliases: tuple[str, ...]
    app: str
    app_legacy: tuple[str, ...]


@dataclass(frozen=True)
class Answer:
    """An HTTP answer: the status, the Location header (or "") and the start of the body."""

    status: int
    location: str = ""
    body: bytes = b""


def _origin(value: object, key: str, path: Path) -> str:
    if not isinstance(value, str) or not _ORIGIN.fullmatch(value):
        raise OriginsError(
            f"{path}: {key} {value!r} is not an https origin in lower case (no port or path)"
        )
    return value


def _origins(value: object, key: str, path: Path) -> tuple[str, ...]:
    if not isinstance(value, list):
        raise OriginsError(f"{path}: {key} must be a list")
    return tuple(_origin(item, key, path) for item in value)


def read_origins(path: Path | None = None) -> Origins:
    """The site's origin and aliases, and the web app's origin and earlier addresses."""
    path = path or ORIGINS
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        site, app = data["site"], data["app"]
        return Origins(
            site=_origin(site["origin"], "site.origin", path),
            site_aliases=_origins(site.get("aliases", []), "site.aliases", path),
            app=_origin(app["origin"], "app.origin", path),
            app_legacy=_origins(app.get("legacy", []), "app.legacy", path),
        )
    except (OSError, json.JSONDecodeError, KeyError, TypeError, AttributeError) as error:
        raise OriginsError(f"{path}: cannot read the origins ({error!r})") from error


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Hands every redirect back as an answer instead of following it."""

    def redirect_request(self, *args, **kwargs):
        return None


def fetch(url: str) -> Answer:
    """One GET of `url`, redirects not followed; raises UnreachableError when no answer came."""
    opener = urllib.request.build_opener(_NoRedirect)
    # The URLs are the https origins of read_origins (or a test's local server).
    headers = {"User-Agent": "maalik-e-makaan-deploy-check"}
    request = urllib.request.Request(url, headers=headers)  # noqa: S310
    try:
        with opener.open(request, timeout=TIMEOUT_SECONDS) as response:
            body = response.read(BODY_LIMIT)
            return Answer(response.status, response.headers.get("Location", ""), body)
    except urllib.error.HTTPError as error:  # a redirect, 4xx or 5xx: an answer all the same
        with error:
            return Answer(error.code, error.headers.get("Location", ""), error.read(BODY_LIMIT))
    except (urllib.error.URLError, OSError) as error:
        raise UnreachableError(str(getattr(error, "reason", error))) from error


Fetch = Callable[[str], Answer]


def answer(url: str, get: Fetch = fetch, sleep: Callable[[float], None] = time.sleep) -> Answer:
    """`get(url)`, tried again while it gets no answer or a 5xx; raises UnreachableError when no
    try got an answer, and returns the last 5xx when every try got one."""
    last: Answer | None = None
    reason: UnreachableError | None = None
    for attempt in range(TRIES):
        if attempt:
            sleep(PAUSE_SECONDS)
        try:
            last = get(url)
        except UnreachableError as error:
            reason = error
            continue
        if last.status < 500:
            return last
    if last is None:
        raise reason or UnreachableError("no answer")
    return last


class Checker:
    """Runs the checks, printing each result; `problems` counts the failures."""

    def __init__(self, get: Fetch = fetch, sleep: Callable[[float], None] = time.sleep) -> None:
        self.get = get
        self.sleep = sleep
        self.problems = 0

    def fail(self, message: str) -> None:
        print(f"::error::{message}")
        self.problems += 1

    def _answer(self, url: str, what: str) -> Answer | None:
        try:
            return answer(url, self.get, self.sleep)
        except UnreachableError as error:
            self.fail(f"{url} does not answer over HTTPS ({error}): {what}")
            return None

    def status(self, url: str, expected: int, what: str) -> Answer | None:
        got = self._answer(url, what)
        if got is None:
            return None
        if got.status != expected:
            self.fail(f"{url} answered {got.status}, not {expected}: {what}")
            return None
        return got

    def redirect(self, url: str, target: str, what: str) -> None:
        got = self.status(url, 308, what)
        if got is None:
            return
        if got.location != target:
            self.fail(f"{url} redirects to {got.location or 'nowhere'}, not {target}: {what}")
            return
        print(f"{url}: 308 to {target}")

    def app(self, origins: Origins) -> None:
        url = f"{origins.app}{ASSETLINKS}"
        got = self.status(
            url, 200, f"the web app's origin must answer before anything names it; {DNS}"
        )
        if got is None:
            return
        try:
            statements = json.loads(got.body)
        except (ValueError, UnicodeDecodeError):
            statements = None
        if not isinstance(statements, list) or not statements:
            self.fail(f"{url} is not a JSON list of statements; Android cannot verify the host")
            return
        print(f"{url}: 200, {len(statements)} statement(s)")

    def site(self, origins: Origins) -> None:
        url = f"{origins.site}/"
        what = f"the site's origin must answer before its old address redirects to it; {DNS}"
        if self.status(url, 200, what):
            print(f"{url}: 200")
        for alias in origins.site_aliases:
            self.redirect(
                f"{alias}/",
                url,
                f"an alias redirects by the Vercel project's domain setting; {DNS}",
            )
        self.app(origins)
        for legacy in origins.app_legacy:
            self.redirect(
                f"{legacy}/",
                f"{origins.app}/",
                "the web app the site links to is not yet the deployment built for its origin;"
                " deploy the web app of this release first (the Release workflow does), or the"
                f" site sends people to a build whose e-mail links name another address ({HELP})",
            )


def main(argv: list[str] | None = None, get: Fetch = fetch) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("part", choices=("app", "site"), help="what is about to be deployed")
    parser.add_argument("--origins", type=Path, help="default: contracts/origins.json")
    args = parser.parse_args(argv)
    try:
        origins = read_origins(args.origins)
    except OriginsError as error:
        print(f"::error::{error}")
        return 2
    checker = Checker(get)
    if args.part == "app":
        checker.app(origins)
    else:
        checker.site(origins)
    if checker.problems:
        print(f"{checker.problems} address check(s) failed; nothing was built or deployed")
        return 1
    print(f"The addresses answer ({args.part})")
    return 0


if __name__ == "__main__":
    sys.exit(main())

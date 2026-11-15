#!/usr/bin/env python3
"""Package the Flutter web build for Vercel (Build Output API v3).

    python3 tool/web/package_vercel.py --build app/build/web \
        --output DIR/.vercel/output --supabase-url https://<ref>.supabase.co

Copies the build into OUTPUT/static and writes OUTPUT/config.json, which
`vercel deploy --prebuilt` uploads as is (no build runs on Vercel). The routes:

1. Security headers on every response, the Content-Security-Policy included,
   and `X-Robots-Tag: noindex`: the website is what search engines index
   (decision D-01), and every path here answers 200 with the app's shell.
2. Cache-Control. A file whose name carries a content hash is immutable for a
   year. Flutter's own output (main.dart.js, canvaskit/, assets/, the entry
   points) keeps the same names from build to build, so everything else,
   index.html and the paths that fall back to it included, is revalidated on
   every load (`no-cache`; unchanged files answer 304).
3. On an earlier address of the web app (`app.legacy` in
   contracts/origins.json, decision D-20): `/` and `/index.html`, and the same
   with more slashes before them (`//`, `//index.html`), answer with the page
   that sends people on to the origin (below), not with the app.
4. `{"handle": "filesystem"}`: existing files are served, on every host.
5. On an earlier address: every other path except /auth/callback answers with
   the same page.
6. Every other path (/auth/callback?code=..., /invite/...) serves index.html
   with status 200, so the app's router handles it.

The page that sends people on (tool/web/moved/, copied to moved.html and
moved.js) is a 200, not a redirect, because the earlier address has to clear
what the app kept in the browser there: the session, the lists the app loaded
(CNICs among them), the settings and an invitation not yet answered. A
browser keeps them for each address apart, and once that address only sends
people on, no app runs there to remove them. The page's response carries
`Clear-Site-Data: "storage"` and nothing else: not "cache" (seconds-long
stalls in Chromium) or "executionContexts" (reloads the page), and not
"cookies" (the app sets none). Its script removes the app's own localStorage
keys, for the browsers that do not know the header (Safari before 17) or do
not act on it here, and replaces the address with the same path, query and
#fragment on the origin; without scripts a meta refresh goes to the origin's
first page. A redirect that carried the header would not do: Chromium and
Firefox act on it for a redirect, WebKit only for the response a navigation
ends on (docs/operations.md, Domains, has the sources).

So an earlier address keeps answering what was sent before the move: the
files, among them `.well-known/assetlinks.json`, which Android checks on each
App Links host without following a redirect, and /auth/callback, which boots
the app where the sign-in verifier of a link requested there is stored.
Neither carries Clear-Site-Data: the header is only on the routes of 3 and 5.
Only those paths as written are kept, the only forms Android and the e-mail
links request: one with a slash more (`//auth/callback`, `/auth//callback`,
`/auth/callback/`, `/.well-known//assetlinks.json`) is another path, which
gets the page of 5 in tool/web/serve_output.py (test_package_vercel pins it);
whether Vercel's filesystem step reads `//.well-known/assetlinks.json` as the
file is not documented, so that one may get either answer there.
Every response carries the security headers and `no-cache`, so browsers ask
again each time. `.well-known/assetlinks.json` is served as application/json.
The Supabase origin is the only backend the CSP allows.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit

ORIGINS = Path(__file__).resolve().parents[2] / "contracts/origins.json"
ASSETLINKS = ".well-known/assetlinks.json"
ASSETLINKS_RELATION = "delegate_permission/common.handle_all_urls"

# Files a Flutter web build must contain; a missing one means a broken build.
REQUIRED_FILES = ("index.html", "flutter_bootstrap.js", "main.dart.js", ASSETLINKS)

# Entry points: always revalidated, even if a future name looked hashed.
ENTRY_POINTS = frozenset(
    {
        "index.html",
        "flutter_service_worker.js",
        "flutter_bootstrap.js",
        "version.json",
        "manifest.json",
        ASSETLINKS,
    }
)

# Build bookkeeping that is not part of the site.
EXCLUDED_FILES = frozenset({".last_build_id"})

# A content hash in a file name: name.0123abcd.ext or name-0123abcd.ext
# (at least 8 hex digits, as bundlers emit).
HASHED_NAME = re.compile(r"[.-][0-9a-f]{8,}\.[A-Za-z0-9]+$")

CACHE_IMMUTABLE = "public, max-age=31536000, immutable"
CACHE_REVALIDATE = "no-cache"

STATIC_HEADERS = {
    "Strict-Transport-Security": "max-age=63072000; includeSubDomains",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "X-Frame-Options": "DENY",
    "Permissions-Policy": (
        "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), "
        "microphone=(), payment=(), usb=()"
    ),
    "Cross-Origin-Opener-Policy": "same-origin",
    # Not a security header: keeps the app's shell, which every path answers, out of search
    # results, where the website stands for the product (D-01). Crawlers still fetch any path,
    # assetlinks.json included.
    "X-Robots-Tag": "noindex",
}

# Flutter's engine downloads fonts for glyphs that the bundled fonts lack
# (other scripts, emoji) from here, with fetch(): its default
# fontFallbackBaseUrl.
FONT_FALLBACK_ORIGIN = "https://fonts.gstatic.com"


# The path an earlier address keeps serving (route 5), besides the files.
KEPT_ON_LEGACY = "auth/callback"

# The page an earlier address answers instead (routes 3 and 5), and its script: the sources,
# and their names in the package.
MOVED_SOURCES = Path(__file__).resolve().parent / "moved"
MOVED_PAGE = "moved.html"
MOVED_SCRIPT = "moved.js"
# What that page's response asks the browser to clear for the earlier address: its storage
# (localStorage, sessionStorage, IndexedDB, service workers), and nothing that would stall or
# reload the page.
CLEAR_SITE_DATA = '"storage"'


class PackagingError(Exception):
    """The build or the arguments cannot be packaged."""


@dataclass(frozen=True)
class AppOrigins:
    """The web app's origin, and the earlier addresses that redirect to it."""

    origin: str
    legacy: tuple[str, ...] = ()

    def legacy_hosts(self) -> tuple[str, ...]:
        return tuple(url.removeprefix("https://") for url in self.legacy)


_ORIGIN = re.compile(r"https://(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}")


def read_app_origins(path: Path | None = None) -> AppOrigins:
    """The web app's entry of contracts/origins.json: https origins, written as browsers send
    them (lower case, no port, path or trailing slash), each named once."""
    path = path or ORIGINS
    try:
        app = json.loads(path.read_text(encoding="utf-8"))["app"]
        origin, legacy = app["origin"], app.get("legacy", [])
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        raise PackagingError(f"{path}: cannot read the web app's origins ({error!r})") from error
    if not isinstance(legacy, list):
        raise PackagingError(f"{path}: app.legacy must be a list")
    for url in [origin, *legacy]:
        if not isinstance(url, str) or not _ORIGIN.fullmatch(url):
            raise PackagingError(
                f"{path}: {url!r} is not an https origin in lower case, without a port or path"
            )
    if len({origin, *legacy}) != 1 + len(legacy):
        raise PackagingError(f"{path}: the web app's origins repeat an address")
    return AppOrigins(origin, tuple(legacy))


def supabase_origin(url: str) -> str:
    """Returns the https origin of the Supabase project URL, or raises."""
    parts = urlsplit(url.strip())
    if parts.scheme != "https" or not parts.hostname:
        raise PackagingError(f"--supabase-url must be an https URL, got {url!r}")
    if parts.username or parts.password or parts.query or parts.fragment:
        raise PackagingError("--supabase-url must not carry credentials, a query or a fragment")
    if parts.path not in ("", "/"):
        raise PackagingError("--supabase-url must be an origin, without a path")
    if not re.fullmatch(r"[a-z0-9.-]+", parts.hostname) or ".." in parts.hostname:
        raise PackagingError(f"--supabase-url has an invalid host: {parts.hostname!r}")
    port = f":{parts.port}" if parts.port else ""
    return f"https://{parts.hostname}{port}"


def content_security_policy(supabase: str) -> str:
    """The CSP for the Flutter web app talking to the Supabase project `supabase`."""
    realtime = "wss://" + supabase.removeprefix("https://")
    directives = {
        "default-src": ["'self'"],
        # CanvasKit is WebAssembly served from this origin; compiling it needs
        # 'wasm-unsafe-eval' (not 'unsafe-eval', which would allow JS eval).
        "script-src": ["'self'", "'wasm-unsafe-eval'"],
        # The engine injects <style> elements (no nonce on a static host).
        "style-src": ["'self'", "'unsafe-inline'"],
        # Storage images; data: and blob: for images decoded in the browser.
        "img-src": ["'self'", "data:", "blob:", supabase],
        "font-src": ["'self'"],
        # Auth, PostgREST, Storage and Realtime (wss); the engine fetch()es
        # fallback fonts for glyphs the bundled fonts lack.
        "connect-src": ["'self'", supabase, realtime, FONT_FALLBACK_ORIGIN],
        # The CanvasKit renderer starts no workers (skwasm, for --wasm builds,
        # would need blob:).
        "worker-src": ["'self'"],
        "manifest-src": ["'self'"],
        "object-src": ["'none'"],
        # index.html sets <base href="/">, which 'none' would block.
        "base-uri": ["'self'"],
        # Flutter wraps autofill groups in a <form> and cancels its submission.
        "form-action": ["'self'"],
        "frame-ancestors": ["'none'"],
    }
    return "; ".join(f"{name} {' '.join(sources)}" for name, sources in directives.items())


def security_headers(supabase: str) -> dict[str, str]:
    return {"Content-Security-Policy": content_security_policy(supabase), **STATIC_HEADERS}


def is_immutable(path: str) -> bool:
    """True for a file whose name carries a content hash (never an entry point)."""
    return path not in ENTRY_POINTS and bool(HASHED_NAME.search(path.rsplit("/", 1)[-1]))


def site_files(build: Path) -> list[str]:
    """The build's files as URL paths without the leading slash, sorted."""
    files = []
    for path in sorted(build.rglob("*")):
        if path.is_file():
            relative = path.relative_to(build).as_posix()
            if relative not in EXCLUDED_FILES:
                files.append(relative)
    return files


def _alternation(paths: list[str]) -> str:
    return "|".join(re.escape(path) for path in paths)


def legacy_routes(app: AppOrigins | None) -> tuple[list[dict], list[dict]]:
    """The routes of the earlier addresses, which answer with the page that clears their storage
    and sends people on: the ones before the filesystem (the root and the page itself, which
    would otherwise be served as files), and the one after it (every other path but the
    callback). None when there is no earlier address."""
    if app is None or not app.legacy:
        return [], []
    # A host holds only [a-z0-9.-] (read_app_origins), so escaping the dots is enough, as in
    # Vercel's own example; a backslash before "-" is an error in some regex dialects.
    hosts = "|".join(host.replace(".", r"\.") for host in app.legacy_hosts())
    moved = {
        "has": [{"type": "host", "value": hosts}],
        "headers": {"Clear-Site-Data": CLEAR_SITE_DATA},
        "dest": f"/{MOVED_PAGE}",
        "status": 200,
    }
    page = re.escape(MOVED_PAGE)
    # "^/+": the root and the page however many slashes lead them ("//", "//index.html"), so
    # they get the page whether or not Vercel's filesystem step reads "//index.html" as the
    # file index.html; the routes after it see the request as sent, "//" and all.
    before = {"src": rf"^/+(?:index\.html|{page})?$", **moved}
    after = {"src": f"^/(?!{KEPT_ON_LEGACY}$).*$", **moved}
    return [before], [after]


def moved_files(app: AppOrigins) -> dict[str, str]:
    """The page an earlier address answers with and its script, by their names in the package,
    with the page's destination filled in: the web app's origin."""
    page = (MOVED_SOURCES / MOVED_PAGE).read_text(encoding="utf-8")
    script = (MOVED_SOURCES / MOVED_SCRIPT).read_text(encoding="utf-8")
    page = page.replace("{{origin}}", app.origin).replace(
        "{{host}}", app.origin.removeprefix("https://")
    )
    if "{{" in page:
        raise PackagingError(f"{MOVED_SOURCES / MOVED_PAGE} has a placeholder with no value")
    return {MOVED_PAGE: page, MOVED_SCRIPT: script}


def build_config(files: list[str], supabase: str, app: AppOrigins | None = None) -> dict:
    """The Build Output API v3 config.json for a build holding `files`, with the redirects of
    `app`'s earlier addresses."""
    immutable = [path for path in files if is_immutable(path)]
    routes: list[dict] = [
        {"src": "^/.*$", "headers": security_headers(supabase), "continue": True},
    ]
    if immutable:
        names = _alternation(immutable)
        routes += [
            {
                "src": f"^/(?:{names})$",
                "headers": {"Cache-Control": CACHE_IMMUTABLE},
                "continue": True,
            },
            {
                "src": f"^/(?!(?:{names})$).*$",
                "headers": {"Cache-Control": CACHE_REVALIDATE},
                "continue": True,
            },
        ]
    else:
        routes.append(
            {"src": "^/.*$", "headers": {"Cache-Control": CACHE_REVALIDATE}, "continue": True}
        )
    before, after = legacy_routes(app)
    routes += [
        *before,
        {"handle": "filesystem"},
        *after,
        {"src": "^/.*$", "dest": "/index.html", "status": 200},
    ]
    return {
        "version": 3,
        "routes": routes,
        "overrides": {ASSETLINKS: {"contentType": "application/json"}},
    }


def check_build(build: Path) -> None:
    if not build.is_dir():
        raise PackagingError(f"{build} is not a directory (run flutter build web first)")
    missing = [name for name in REQUIRED_FILES if not (build / name).is_file()]
    if missing:
        raise PackagingError(f"{build} lacks {', '.join(missing)}")
    try:
        statements = json.loads((build / ASSETLINKS).read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise PackagingError(f"{ASSETLINKS} is not valid JSON: {error}") from error
    if not isinstance(statements, list) or not statements:
        raise PackagingError(f"{ASSETLINKS} must be a non-empty list of statements")
    for statement in statements:
        statement = statement if isinstance(statement, dict) else {}
        target = statement.get("target") or {}
        fingerprints = target.get("sha256_cert_fingerprints")
        if (
            ASSETLINKS_RELATION not in statement.get("relation", [])
            or target.get("namespace") != "android_app"
            or not target.get("package_name")
            or not fingerprints
            or not all(re.fullmatch(r"([0-9A-F]{2}:){31}[0-9A-F]{2}", f) for f in fingerprints)
        ):
            raise PackagingError(
                f"{ASSETLINKS}: every statement needs relation {ASSETLINKS_RELATION}, an "
                "android_app package_name and upper-case SHA-256 fingerprints (AA:BB:...)"
            )


def prepare_output(output: Path) -> None:
    """Empties `output`, refusing anything that is not a Build Output directory."""
    if output.exists():
        if not output.is_dir():
            raise PackagingError(f"{output} exists and is not a directory")
        entries = {entry.name for entry in output.iterdir()}
        if entries and not entries <= {"config.json", "static"}:
            raise PackagingError(f"{output} holds other files; refusing to replace it")
        shutil.rmtree(output)
    output.mkdir(parents=True)


def package(build: Path, output: Path, supabase_url: str, origins: Path | None = None) -> dict:
    """Writes the Build Output directory and returns its config. The web app's origins come
    from contracts/origins.json unless `origins` names another file."""
    supabase = supabase_origin(supabase_url)
    app = read_app_origins(origins)
    check_build(build)
    files = site_files(build)
    taken = sorted({MOVED_PAGE, MOVED_SCRIPT} & set(files)) if app.legacy else []
    if taken:
        raise PackagingError(
            f"{build} already holds {', '.join(taken)}, the name of the page an earlier address"
            " answers with"
        )
    prepare_output(output)
    static = output / "static"
    for relative in files:
        target = static / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(build / relative, target)
    if app.legacy:
        for name, text in moved_files(app).items():
            (static / name).write_text(text, encoding="utf-8")
            files.append(name)
    config = build_config(sorted(files), supabase, app)
    (output / "config.json").write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    return config


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--build", type=Path, required=True, help="flutter build web output")
    parser.add_argument("--output", type=Path, required=True, help="the .vercel/output directory")
    parser.add_argument("--supabase-url", required=True, help="the project's https origin")
    args = parser.parse_args(argv)
    try:
        config = package(args.build, args.output, args.supabase_url)
    except PackagingError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    count = sum(1 for path in (args.output / "static").rglob("*") if path.is_file())
    print(f"Packaged {count} files into {args.output} ({len(config['routes'])} routes)")
    earlier = [route for route in config["routes"] if "has" in route]
    if earlier:
        hosts = earlier[0]["has"][0]["value"]
        print(f"Earlier addresses ({hosts}) clear their storage and send people to the origin")
    return 0


if __name__ == "__main__":
    sys.exit(main())

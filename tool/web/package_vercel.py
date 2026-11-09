#!/usr/bin/env python3
"""Package the Flutter web build for Vercel (Build Output API v3).

    python3 tool/web/package_vercel.py --build app/build/web \
        --output DIR/.vercel/output --supabase-url https://<ref>.supabase.co

Copies the build into OUTPUT/static and writes OUTPUT/config.json, which
`vercel deploy --prebuilt` uploads as is (no build runs on Vercel). The routes:

1. Security headers on every response, the Content-Security-Policy included.
2. Cache-Control. A file whose name carries a content hash is immutable for a
   year. Flutter's own output (main.dart.js, canvaskit/, assets/, the entry
   points) keeps the same names from build to build, so everything else,
   index.html and the paths that fall back to it included, is revalidated on
   every load (`no-cache`; unchanged files answer 304).
3. `{"handle": "filesystem"}`: existing files are served.
4. Every other path (/auth/callback?code=..., /invite/...) serves index.html
   with status 200, so the app's router handles it.

`.well-known/assetlinks.json` (Android App Links) is served as
application/json. The Supabase origin is the only backend the CSP allows.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path
from urllib.parse import urlsplit

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
}

# Flutter's engine downloads fonts for glyphs that the bundled fonts lack
# (other scripts, emoji) from here, with fetch(): its default
# fontFallbackBaseUrl.
FONT_FALLBACK_ORIGIN = "https://fonts.gstatic.com"


class PackagingError(Exception):
    """The build or the arguments cannot be packaged."""


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


def build_config(files: list[str], supabase: str) -> dict:
    """The Build Output API v3 config.json for a build holding `files`."""
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
    routes += [
        {"handle": "filesystem"},
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


def package(build: Path, output: Path, supabase_url: str) -> dict:
    """Writes the Build Output directory and returns its config."""
    supabase = supabase_origin(supabase_url)
    check_build(build)
    files = site_files(build)
    prepare_output(output)
    static = output / "static"
    for relative in files:
        target = static / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(build / relative, target)
    config = build_config(files, supabase)
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
    return 0


if __name__ == "__main__":
    sys.exit(main())

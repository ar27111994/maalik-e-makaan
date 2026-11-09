#!/usr/bin/env python3
"""Serve a Flutter web build for the UAT suite, the way production serves it.

    python3 tool/uat/serve_app.py BUILD_DIR --supabase-url http://127.0.0.1:54321 [--port 8080]

Packages BUILD_DIR with tool/web/package_vercel.py's routes (security headers,
the Content-Security-Policy, cache rules and the index.html fallback) and
serves it with tool/web/serve_output.py. The only change from production is
the backend origin: the local Supabase stack answers on plain http on the
loopback interface, which package_vercel refuses for a real deploy, so the CSP
here names that http origin (and ws:// for Realtime) instead of https.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool" / "web"))

import package_vercel  # noqa: E402
import serve_output  # noqa: E402


def local_origin(url: str) -> str:
    """The http origin of a loopback Supabase URL, or raises ValueError."""
    parts = urlsplit(url.strip())
    if parts.scheme != "http" or parts.hostname not in {"127.0.0.1", "localhost"}:
        raise ValueError(f"--supabase-url must be http on the loopback interface, got {url!r}")
    if parts.path not in ("", "/") or parts.query or parts.fragment:
        raise ValueError("--supabase-url must be an origin, without a path")
    port = f":{parts.port}" if parts.port else ""
    return f"http://{parts.hostname}{port}"


def local_config(files: list[str], origin: str) -> dict:
    """package_vercel's config.json with the CSP pointed at the local stack."""
    placeholder = "https://uat.invalid"
    config = package_vercel.build_config(files, placeholder)
    text = json.dumps(config)
    text = text.replace("wss://uat.invalid", origin.replace("http://", "ws://", 1))
    text = text.replace(placeholder, origin)
    return json.loads(text)


def package(build: Path, output: Path, supabase_url: str) -> None:
    origin = local_origin(supabase_url)
    if not (build / "index.html").is_file() or not (build / "main.dart.js").is_file():
        raise ValueError(f"{build} is not a Flutter web build (run flutter build web first)")
    files = package_vercel.site_files(build)
    static = output / "static"
    shutil.copytree(build, static)
    config = local_config(files, origin)
    (output / "config.json").write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("build", type=Path, help="flutter build web output")
    parser.add_argument("--supabase-url", required=True, help="the local stack's API URL")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args(argv)
    with tempfile.TemporaryDirectory(prefix="mm-uat-web-") as temporary:
        output = Path(temporary) / "output"
        try:
            package(args.build, output, args.supabase_url)
        except ValueError as error:
            print(f"error: {error}", file=sys.stderr)
            return 2
        server = serve_output.serve(output, port=args.port)
        print(f"Serving {args.build} on http://127.0.0.1:{server.server_address[1]}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())

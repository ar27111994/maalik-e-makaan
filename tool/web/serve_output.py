#!/usr/bin/env python3
"""Serve a Build Output API v3 directory locally, the way Vercel routes it.

    python3 tool/web/serve_output.py OUTPUT_DIR [--port 8080]

Reads OUTPUT_DIR/config.json and applies its routes to OUTPUT_DIR/static, so a
browser test exercises the exact headers, CSP and fallback that production
serves. Only the route features package_vercel.py emits are understood
(header routes that continue, the filesystem handle, rewrites after it,
content-type overrides); anything else is refused rather than half-served.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import re
import sys
from dataclasses import dataclass, field
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

SUPPORTED_KEYS = frozenset({"src", "headers", "continue", "dest", "status", "caseSensitive"})

CONTENT_TYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".mjs": "text/javascript; charset=utf-8",
    ".json": "application/json",
    ".wasm": "application/wasm",
    ".css": "text/css; charset=utf-8",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".ttf": "font/ttf",
    ".otf": "font/otf",
    ".woff2": "font/woff2",
}


class UnsupportedConfigError(Exception):
    """config.json uses a routing feature this server does not implement."""


@dataclass
class Response:
    status: int
    file: Path | None
    headers: dict[str, str] = field(default_factory=dict)


@dataclass
class Router:
    """The routes of a Build Output config, split around the filesystem handle."""

    static: Path
    before: list[tuple[re.Pattern[str], dict]]
    after: list[tuple[re.Pattern[str], dict]]
    overrides: dict[str, dict]

    @classmethod
    def load(cls, output: Path) -> Router:
        config = json.loads((output / "config.json").read_text(encoding="utf-8"))
        if config.get("version") != 3:
            raise UnsupportedConfigError("config.json must declare version 3")
        before: list[tuple[re.Pattern[str], dict]] = []
        after: list[tuple[re.Pattern[str], dict]] = []
        current = before
        for route in config.get("routes", []):
            if "handle" in route:
                if route != {"handle": "filesystem"} or current is after:
                    raise UnsupportedConfigError(f"unsupported handler {route}")
                current = after
                continue
            unknown = set(route) - SUPPORTED_KEYS
            if unknown:
                raise UnsupportedConfigError(f"unsupported route keys {sorted(unknown)}")
            if current is before and not (route.get("continue") and "dest" not in route):
                raise UnsupportedConfigError("routes before the filesystem must only add headers")
            if current is after and "dest" not in route:
                raise UnsupportedConfigError("routes after the filesystem must rewrite")
            # Vercel matches paths case-insensitively unless told otherwise.
            flags = 0 if route.get("caseSensitive") else re.IGNORECASE
            current.append((re.compile(route["src"], flags), route))
        return cls(output / "static", before, after, config.get("overrides", {}))

    def _file(self, path: str) -> Path | None:
        relative = path.lstrip("/") or "index.html"
        candidate = (self.static / relative).resolve()
        root = self.static.resolve()
        if root not in candidate.parents and candidate != root:
            return None
        if candidate.is_dir():
            candidate = candidate / "index.html"
        return candidate if candidate.is_file() else None

    def resolve(self, raw_path: str) -> Response:
        path = unquote(urlsplit(raw_path).path) or "/"
        headers: dict[str, str] = {}
        for pattern, route in self.before:
            if pattern.search(path):
                headers.update(route.get("headers", {}))
        file = self._file(path)
        if file:
            return Response(HTTPStatus.OK, file, headers)
        for pattern, route in self.after:
            if pattern.search(path):
                headers.update(route.get("headers", {}))
                return Response(
                    route.get("status", HTTPStatus.OK), self._file(route["dest"]), headers
                )
        return Response(HTTPStatus.NOT_FOUND, None, headers)

    def content_type(self, file: Path) -> str:
        relative = file.relative_to(self.static.resolve()).as_posix()
        override = self.overrides.get(relative, {}).get("contentType")
        if override:
            return override
        return (
            CONTENT_TYPES.get(file.suffix)
            or mimetypes.guess_type(file.name)[0]
            or "application/octet-stream"
        )


def handler_for(router: Router) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        def _respond(self, body: bool) -> None:
            response = router.resolve(self.path)
            payload = response.file.read_bytes() if response.file else b"Not found\n"
            self.send_response(response.status)
            for name, value in response.headers.items():
                self.send_header(name, value)
            content_type = router.content_type(response.file) if response.file else "text/plain"
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            if body:
                self.wfile.write(payload)

        def do_GET(self) -> None:
            self._respond(body=True)

        def do_HEAD(self) -> None:
            self._respond(body=False)

        def log_message(self, format: str, *args: object) -> None:
            pass

    return Handler


def serve(output: Path, port: int = 0, host: str = "127.0.0.1") -> ThreadingHTTPServer:
    """A server for `output`, bound but not yet serving (call serve_forever)."""
    return ThreadingHTTPServer((host, port), handler_for(Router.load(output)))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("output", type=Path, help="the .vercel/output directory")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args(argv)
    try:
        server = serve(args.output, args.port)
    except (OSError, UnsupportedConfigError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    host, port = server.server_address[:2]
    print(f"Serving {args.output} on http://{host}:{port}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())

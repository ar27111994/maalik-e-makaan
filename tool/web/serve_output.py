#!/usr/bin/env python3
"""Serve a Build Output API v3 directory locally, the way Vercel routes it.

    python3 tool/web/serve_output.py OUTPUT_DIR [--port 8080]

Reads OUTPUT_DIR/config.json and applies its routes to OUTPUT_DIR/static, so a
browser test exercises the exact headers, CSP, pages and fallback that
production serves. Only the route features package_vercel.py emits are
understood: header routes that continue, rewrites to a static file before or
after the filesystem handle (with their own headers and status), `has`
conditions on the host, and content-type overrides. Anything else is refused
rather than half-served. The host is the request's Host header without its
port, so `curl -H 'Host: <an earlier address>'` sees what that address would. The path is the
request target up to its query, so `//x/y` is the path `//x/y`, as on Vercel, not `/y` on the
host x; a target that is not a path (absolute-form, `*`) answers 400. The file lookup takes that
same path, so one with an empty segment (`//`, `/a//b`) names no file and is left to the routes
after the filesystem.
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
from urllib.parse import unquote

SUPPORTED_KEYS = frozenset({"src", "headers", "continue", "dest", "status", "caseSensitive", "has"})

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


def _check_rewrite(route: dict) -> None:
    """A rewrite names a static file and ends the routing: no pattern groups, query, other
    origin or status but 200, none of which package_vercel.py writes."""
    dest = route["dest"]
    if (
        not isinstance(dest, str)
        or not dest.startswith("/")
        or dest.startswith("//")
        or any(char in dest for char in "$?#")
    ):
        raise UnsupportedConfigError(f"a rewrite goes to a static file, got {dest!r}")
    if route.get("continue"):
        raise UnsupportedConfigError("a rewrite does not continue")
    if route.get("status", HTTPStatus.OK) != HTTPStatus.OK:
        raise UnsupportedConfigError(f"a rewrite answers 200, got {route['status']!r}")


def _check_has(route: dict) -> None:
    has = route.get("has")
    if has is None:
        return
    if (
        not isinstance(has, list)
        or not has
        or not all(
            isinstance(c, dict)
            and set(c) == {"type", "value"}
            and c["type"] == "host"
            and isinstance(c["value"], str)
            for c in has
        )
    ):
        raise UnsupportedConfigError(f"only host conditions are supported in has, got {has!r}")


def _host_matches(route: dict, host: str) -> bool:
    """Every `has` host condition matches the whole host name (a regex, as on Vercel)."""
    return all(re.fullmatch(c["value"], host) for c in route.get("has", []))


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
            _check_has(route)
            if "dest" in route:
                _check_rewrite(route)
            elif current is after:
                raise UnsupportedConfigError("routes after the filesystem must rewrite")
            elif not route.get("continue") or "status" in route:
                raise UnsupportedConfigError(
                    "routes before the filesystem must add headers and continue, or rewrite"
                )
            # Vercel matches paths case-insensitively unless told otherwise.
            flags = 0 if route.get("caseSensitive") else re.IGNORECASE
            current.append((re.compile(route["src"], flags), route))
        return cls(output / "static", before, after, config.get("overrides", {}))

    def _file(self, path: str) -> Path | None:
        """The static file `path` names, or None. The path is the one the routes matched, so a
        path with an empty segment ("//", "//index.html", "/a//b") names no file: collapsing it
        here would serve, say, index.html for "//" behind the back of a route that did not match
        "//" and so leave that request to the routes after the filesystem."""
        if "//" in path:
            return None
        relative = path.removeprefix("/") or "index.html"
        candidate = (self.static / relative).resolve()
        root = self.static.resolve()
        if root not in candidate.parents and candidate != root:
            return None
        if candidate.is_dir():
            candidate = candidate / "index.html"
        return candidate if candidate.is_file() else None

    def _rewritten(self, route: dict, headers: dict[str, str]) -> Response:
        """The file a rewrite names, with the headers gathered so far and the route's own."""
        headers = {**headers, **route.get("headers", {})}
        file = self._file(route["dest"])
        return Response(HTTPStatus.OK if file else HTTPStatus.NOT_FOUND, file, headers)

    def resolve(self, raw_path: str, host: str = "localhost") -> Response:
        """The response to a request for `raw_path` (with its query) on `host`."""
        if not raw_path.startswith("/"):
            return Response(HTTPStatus.BAD_REQUEST, None)
        # Up to the query (or a fragment, which a client should not send): urlsplit would read
        # a target that starts with // as a host and the rest as the path.
        path = unquote(re.split(r"[?#]", raw_path, maxsplit=1)[0])
        headers: dict[str, str] = {}
        for pattern, route in self.before:
            if not (_host_matches(route, host) and pattern.search(path)):
                continue
            if "dest" in route:
                return self._rewritten(route, headers)
            headers.update(route.get("headers", {}))
        file = self._file(path)
        if file:
            return Response(HTTPStatus.OK, file, headers)
        for pattern, route in self.after:
            if _host_matches(route, host) and pattern.search(path):
                return self._rewritten(route, headers)
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
            # The Host header without its port ("[::1]:8080" keeps its brackets).
            host = re.sub(r":\d+$", "", self.headers.get("Host", "localhost")).lower()
            # The target as the client sent it: http.server reduces a leading // in self.path
            # to one /, and Vercel does not.
            words = self.requestline.split()
            response = router.resolve(words[1] if len(words) > 1 else self.path, host)
            if response.file:
                payload = response.file.read_bytes()
            else:
                payload = HTTPStatus(response.status).phrase.encode() + b"\n"
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

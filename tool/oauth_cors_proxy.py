#!/usr/bin/env python3
"""Tiny CORS proxy for xAI OAuth when running Aether on Flutter web.

auth.x.ai does not send Access-Control-Allow-Origin, so browser builds
cannot talk to it directly. Native Android/Windows/iOS do not need this.

Usage:
  python3 tool/oauth_cors_proxy.py
  flutter run -d chrome --dart-define=AETHER_OAUTH_PROXY=http://127.0.0.1:8787
"""

from __future__ import annotations

import http.client
import http.server
import sys
import urllib.parse

HOST = "127.0.0.1"
PORT = 8787
UPSTREAM = "auth.x.ai"


class Handler(http.server.BaseHTTPRequestHandler):
    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, Accept, User-Agent",
        )

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        if not parsed.path.startswith("/oauth2/"):
            self.send_response(404)
            self._cors()
            self.end_headers()
            self.wfile.write(b"not found")
            return

        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else b""

        conn = http.client.HTTPSConnection(UPSTREAM, timeout=30)
        headers = {
            "Content-Type": self.headers.get(
                "Content-Type", "application/x-www-form-urlencoded"
            ),
            "Accept": "application/json",
            "User-Agent": self.headers.get("User-Agent", "aether-oauth-proxy/1.0"),
        }
        try:
            conn.request("POST", parsed.path, body=body, headers=headers)
            upstream = conn.getresponse()
            payload = upstream.read()
            self.send_response(upstream.status)
            self._cors()
            ctype = upstream.getheader("Content-Type") or "application/json"
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        finally:
            conn.close()

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main() -> None:
    server = http.server.ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Aether OAuth CORS proxy on http://{HOST}:{PORT}", flush=True)
    print("Forwarding POST /oauth2/* → https://auth.x.ai/oauth2/*", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()

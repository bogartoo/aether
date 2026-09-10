#!/usr/bin/env python3
"""Serve HRTBRKR Flutter web + a same-origin mock Edge0 API for demos.

Usage:
  flutter build web --release
  python3 tool/demo_web_server.py --port 8080

Then open http://127.0.0.1:8080 — Connect uses this host as the Edge0 base URL.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

MODEL = "edge0-8b"
ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "build" / "web"


def _chat_reply(payload: dict) -> str:
    msgs = payload.get("messages") or []
    last = ""
    for m in msgs:
        if isinstance(m, dict) and m.get("role") == "user":
            last = str(m.get("content") or "")
    last = last.strip() or "there"
    return (
        f"HRTBRKR demo here — local Edge0 stub, not the real MLX model. "
        f"You said: {last[:240]}"
    )


class Handler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

    def _json(self, code: int, obj):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self._cors()
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):  # noqa: N802
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path == "/healthz":
            self._json(200, {"status": "ok", "model": MODEL})
            return
        if path == "/v1/models":
            self._json(
                200,
                {
                    "object": "list",
                    "data": [
                        {"id": MODEL, "object": "model", "owned_by": "edge0"},
                        {"id": "edge0-35b", "object": "model", "owned_by": "edge0"},
                    ],
                },
            )
            return
        self._static(path)

    def do_POST(self):  # noqa: N802
        path = self.path.split("?", 1)[0]
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw.decode("utf-8") or "{}")
        except Exception:
            payload = {}

        if path != "/v1/chat/completions":
            self._json(404, {"error": {"message": f"no route {path}"}})
            return

        reply = _chat_reply(payload)
        if payload.get("stream"):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self._cors()
            self.end_headers()
            # Stream in small chunks so the UI animates.
            for i in range(0, len(reply), 8):
                piece = reply[i : i + 8]
                chunk = {
                    "id": "chatcmpl-demo",
                    "object": "chat.completion.chunk",
                    "model": MODEL,
                    "choices": [
                        {
                            "index": 0,
                            "delta": {"content": piece},
                            "finish_reason": None,
                        }
                    ],
                }
                self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode("utf-8"))
                self.wfile.flush()
            done = {
                "id": "chatcmpl-demo",
                "object": "chat.completion.chunk",
                "model": MODEL,
                "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
            }
            self.wfile.write(f"data: {json.dumps(done)}\n\n".encode("utf-8"))
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
            return

        self._json(
            200,
            {
                "id": "chatcmpl-demo",
                "object": "chat.completion",
                "model": MODEL,
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": reply},
                        "finish_reason": "stop",
                    }
                ],
            },
        )

    def _static(self, path: str):
        if not WEB.is_dir():
            self._json(
                500,
                {
                    "error": {
                        "message": "build/web missing — run: flutter build web --release"
                    }
                },
            )
            return
        rel = path.lstrip("/") or "index.html"
        candidate = (WEB / rel).resolve()
        try:
            candidate.relative_to(WEB.resolve())
        except ValueError:
            self.send_error(403)
            return
        if candidate.is_dir():
            candidate = candidate / "index.html"
        if not candidate.is_file():
            # Flutter SPA fallback
            candidate = WEB / "index.html"
        data = candidate.read_bytes()
        ctype = mimetypes.guess_type(str(candidate))[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self._cors()
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        print("[%s] %s" % (self.log_date_time_string(), fmt % args), flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=8080)
    args = ap.parse_args()
    if not WEB.is_dir():
        raise SystemExit(f"Missing {WEB} — run `flutter build web --release` first")
    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    print(
        f"HRTBRKR demo web on http://{args.host}:{args.port}  (mock Edge0 same-origin)",
        flush=True,
    )
    httpd.serve_forever()


if __name__ == "__main__":
    main()

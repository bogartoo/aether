#!/usr/bin/env python3
"""Serve HRTBRKR Flutter web and proxy chat to a real local LLM.

Upstream is an OpenAI-compatible server:
  - Ollama:  http://127.0.0.1:11434/v1   (Linux / Windows / Mac)
  - Edge0:   http://127.0.0.1:8000       (Apple Silicon + `edge0 serve`)

Usage:
  flutter build web --release
  # Terminal A — real model:
  ollama serve && ollama pull llama3.2:3b
  # or: edge0 serve edge0-8b

  # Terminal B — HRTBRKR web + proxy:
  HRTBRKR_LLM_BASE=http://127.0.0.1:11434/v1 \\
  HRTBRKR_LLM_MODEL=llama3.2:3b \\
    python3 tool/hrtbrkr_web_server.py --port 8080
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "build" / "web"

DEFAULT_UPSTREAM = os.environ.get("HRTBRKR_LLM_BASE", "http://127.0.0.1:11434/v1").rstrip("/")
DEFAULT_MODEL = os.environ.get("HRTBRKR_LLM_MODEL", "llama3.2:3b")


def _upstream_url(path: str) -> str:
    if not path.startswith("/"):
        path = "/" + path
    # Upstream already includes /v1 — map our public paths.
    if path == "/healthz":
        # Ollama has /api/tags; Edge0 has /healthz. Probe models list.
        if DEFAULT_UPSTREAM.endswith("/v1"):
            return DEFAULT_UPSTREAM + "/models"
        return DEFAULT_UPSTREAM.rstrip("/") + "/healthz"
    if path.startswith("/v1/"):
        suffix = path[len("/v1") :]
        if DEFAULT_UPSTREAM.endswith("/v1"):
            return DEFAULT_UPSTREAM + suffix
        return DEFAULT_UPSTREAM.rstrip("/") + path
    return DEFAULT_UPSTREAM + path


def _proxy(method: str, path: str, body: bytes | None, headers: dict) -> tuple[int, dict, bytes]:
    url = _upstream_url(path)
    req_headers = {
        "Content-Type": headers.get("Content-Type", "application/json"),
        "Accept": headers.get("Accept", "*/*"),
        "User-Agent": "hrtbrkr-web-proxy/1.0",
    }
    # Force model name if client omitted / sent an Edge0 tier alias.
    if method == "POST" and body and path.endswith("/chat/completions"):
        try:
            payload = json.loads(body.decode("utf-8") or "{}")
        except Exception:
            payload = {}
        model = payload.get("model") or ""
        if not model or model.startswith("edge0-"):
            payload["model"] = DEFAULT_MODEL
            body = json.dumps(payload).encode("utf-8")
        req_headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=body, headers=req_headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=600) as resp:
            raw = resp.read()
            out_headers = {
                "Content-Type": resp.headers.get("Content-Type", "application/json"),
            }
            return resp.status, out_headers, raw
    except urllib.error.HTTPError as e:
        raw = e.read()
        return e.code, {"Content-Type": e.headers.get("Content-Type", "application/json")}, raw
    except Exception as e:
        err = json.dumps(
            {
                "error": {
                    "message": (
                        f"Cannot reach local LLM at {DEFAULT_UPSTREAM}: {e}. "
                        "Start Ollama (`ollama serve`) or Edge0 (`edge0 serve`)."
                    ),
                    "type": "upstream_unreachable",
                }
            }
        ).encode("utf-8")
        return 502, {"Content-Type": "application/json"}, err


def _proxy_stream(method: str, path: str, body: bytes | None, headers: dict, write):
    """Stream SSE from upstream to the client."""
    url = _upstream_url(path)
    if body and path.endswith("/chat/completions"):
        try:
            payload = json.loads(body.decode("utf-8") or "{}")
        except Exception:
            payload = {}
        model = payload.get("model") or ""
        if not model or model.startswith("edge0-"):
            payload["model"] = DEFAULT_MODEL
        payload["stream"] = True
        body = json.dumps(payload).encode("utf-8")

    req_headers = {
        "Content-Type": "application/json",
        "Accept": "text/event-stream",
        "User-Agent": "hrtbrkr-web-proxy/1.0",
    }
    request = urllib.request.Request(url, data=body, headers=req_headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=600) as resp:
            while True:
                chunk = resp.read(256)
                if not chunk:
                    break
                write(chunk)
    except Exception as e:
        err = {
            "error": {
                "message": f"Upstream stream failed: {e}",
                "type": "upstream_error",
            }
        }
        write(f"data: {json.dumps(err)}\n\n".encode("utf-8"))
        write(b"data: [DONE]\n\n")


class Handler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

    def do_OPTIONS(self):  # noqa: N802
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path == "/healthz":
            status, hdrs, raw = _proxy("GET", "/healthz", None, dict(self.headers))
            # Normalize to Edge0-style health for the Flutter client.
            model = DEFAULT_MODEL
            ok = status < 400
            try:
                data = json.loads(raw.decode("utf-8") or "{}")
                if isinstance(data, dict):
                    if data.get("model"):
                        model = data["model"]
                    elif data.get("data") and isinstance(data["data"], list) and data["data"]:
                        model = data["data"][0].get("id") or model
                    if data.get("status") == "ok":
                        ok = True
            except Exception:
                pass
            body = json.dumps(
                {"status": "ok" if ok else "error", "model": model, "upstream": DEFAULT_UPSTREAM}
            ).encode("utf-8")
            self.send_response(200 if ok else 502)
            self.send_header("Content-Type", "application/json")
            self._cors()
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if path.startswith("/v1/"):
            status, hdrs, raw = _proxy("GET", path, None, dict(self.headers))
            self.send_response(status)
            self.send_header("Content-Type", hdrs.get("Content-Type", "application/json"))
            self._cors()
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
            return
        self._static(path)

    def do_POST(self):  # noqa: N802
        path = self.path.split("?", 1)[0]
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b"{}"
        if path != "/v1/chat/completions":
            msg = json.dumps({"error": {"message": f"no route {path}"}}).encode()
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self._cors()
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
            return

        stream = False
        try:
            stream = bool(json.loads(body.decode("utf-8") or "{}").get("stream"))
        except Exception:
            stream = False

        if stream:
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self._cors()
            self.end_headers()

            def write(chunk: bytes):
                self.wfile.write(chunk)
                self.wfile.flush()

            _proxy_stream("POST", path, body, dict(self.headers), write)
            return

        status, hdrs, raw = _proxy("POST", path, body, dict(self.headers))
        self.send_response(status)
        self.send_header("Content-Type", hdrs.get("Content-Type", "application/json"))
        self._cors()
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _static(self, path: str):
        if not WEB.is_dir():
            msg = json.dumps(
                {"error": {"message": "build/web missing — run: flutter build web --release"}}
            ).encode()
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self._cors()
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
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
    print(
        f"HRTBRKR web → real LLM upstream {DEFAULT_UPSTREAM} (model={DEFAULT_MODEL})",
        flush=True,
    )
    print(f"Open http://{args.host}:{args.port}", flush=True)
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()

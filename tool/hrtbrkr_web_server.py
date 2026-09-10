#!/usr/bin/env python3
"""Serve HRTBRKR Flutter web, proxy chat to a real local LLM, and generate images.

Upstream chat (OpenAI-compatible):
  - Ollama:  http://127.0.0.1:11434/v1
  - Edge0:   http://127.0.0.1:8000

Image backends (first that works):
  1) HRTBRKR_SD_BASE — AUTOMATIC1111 / Forge / SD.Next  (.../sdapi/v1/txt2img)
  2) Pollinations (https://image.pollinations.ai) — no key, adult-friendly

Usage:
  ollama create hrtbrkr -f tool/Modelfile.hrtbrkr
  ollama serve
  flutter build web --release
  HRTBRKR_LLM_MODEL=hrtbrkr python3 tool/hrtbrkr_web_server.py --port 8080
"""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "build" / "web"

DEFAULT_UPSTREAM = os.environ.get("HRTBRKR_LLM_BASE", "http://127.0.0.1:11434/v1").rstrip("/")
DEFAULT_MODEL = os.environ.get("HRTBRKR_LLM_MODEL", "hrtbrkr")
SD_BASE = os.environ.get("HRTBRKR_SD_BASE", "").rstrip("/")
POLLINATIONS = os.environ.get(
    "HRTBRKR_IMAGE_URL",
    "https://image.pollinations.ai/prompt/{prompt}",
)


def _upstream_url(path: str) -> str:
    if not path.startswith("/"):
        path = "/" + path
    if path == "/healthz":
        if DEFAULT_UPSTREAM.endswith("/v1"):
            return DEFAULT_UPSTREAM + "/models"
        return DEFAULT_UPSTREAM.rstrip("/") + "/healthz"
    if path.startswith("/v1/"):
        suffix = path[len("/v1") :]
        if DEFAULT_UPSTREAM.endswith("/v1"):
            return DEFAULT_UPSTREAM + suffix
        return DEFAULT_UPSTREAM.rstrip("/") + path
    return DEFAULT_UPSTREAM + path


def _http_json(method: str, url: str, body: bytes | None = None, timeout: int = 600):
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "hrtbrkr-web-proxy/1.0",
        },
        method=method,
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.status, resp.read()


def _generate_image(prompt: str, width: int = 768, height: int = 768) -> dict:
    """Return OpenAI-style {data:[{url|b64_json}]}."""
    prompt = (prompt or "abstract art").strip() or "abstract art"
    # 1) Local Stable Diffusion WebUI
    if SD_BASE:
        payload = json.dumps(
            {
                "prompt": prompt,
                "negative_prompt": "child, loli, shota, underage, underage",
                "steps": 20,
                "width": width,
                "height": height,
                "cfg_scale": 7,
            }
        ).encode("utf-8")
        try:
            status, raw = _http_json("POST", f"{SD_BASE}/sdapi/v1/txt2img", payload, timeout=300)
            if status < 400:
                data = json.loads(raw.decode("utf-8"))
                images = data.get("images") or []
                if images:
                    return {
                        "created": 0,
                        "data": [{"b64_json": images[0], "revised_prompt": prompt}],
                    }
        except Exception as e:
            print(f"[hrtbrkr] SD backend failed: {e}", flush=True)

    # 2) Pollinations — returns raw image bytes at a prompt URL
    q = urllib.parse.quote(prompt, safe="")
    url = POLLINATIONS.format(prompt=q)
    # Add params for size / no logo / seed-ish
    sep = "&" if "?" in url else "?"
    url = f"{url}{sep}width={width}&height={height}&nologo=true&safe=false"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "hrtbrkr/1.0"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            img = resp.read()
            ctype = resp.headers.get("Content-Type", "image/jpeg")
        b64 = base64.b64encode(img).decode("ascii")
        return {
            "created": 0,
            "data": [
                {
                    "b64_json": b64,
                    "url": f"data:{ctype};base64,{b64}",
                    "revised_prompt": prompt,
                }
            ],
        }
    except Exception as e:
        raise RuntimeError(f"Image generation failed: {e}") from e


def _proxy(method: str, path: str, body: bytes | None, headers: dict) -> tuple[int, dict, bytes]:
    url = _upstream_url(path)
    req_headers = {
        "Content-Type": headers.get("Content-Type", "application/json"),
        "Accept": headers.get("Accept", "*/*"),
        "User-Agent": "hrtbrkr-web-proxy/1.0",
    }
    if method == "POST" and body and path.endswith("/chat/completions"):
        try:
            payload = json.loads(body.decode("utf-8") or "{}")
        except Exception:
            payload = {}
        model = payload.get("model") or ""
        if not model or model.startswith("edge0-") or model in ("llama3.2:3b",):
            # Prefer the uncensored HRTBRKR model when aliases are used.
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
    url = _upstream_url(path)
    if body and path.endswith("/chat/completions"):
        try:
            payload = json.loads(body.decode("utf-8") or "{}")
        except Exception:
            payload = {}
        model = payload.get("model") or ""
        if not model or model.startswith("edge0-") or model in ("llama3.2:3b",):
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
            status, hdrs, raw = _proxy("GET", "/healthz", None, dict(self.headers))
            model = DEFAULT_MODEL
            ok = status < 400
            try:
                data = json.loads(raw.decode("utf-8") or "{}")
                if isinstance(data, dict):
                    if data.get("model"):
                        model = data["model"]
                    elif data.get("data") and isinstance(data["data"], list) and data["data"]:
                        # Prefer hrtbrkr if listed
                        ids = [x.get("id") for x in data["data"] if isinstance(x, dict)]
                        if DEFAULT_MODEL in ids:
                            model = DEFAULT_MODEL
                        elif ids:
                            model = ids[0] or model
            except Exception:
                pass
            self._json(
                200 if ok else 502,
                {
                    "status": "ok" if ok else "error",
                    "model": model,
                    "upstream": DEFAULT_UPSTREAM,
                    "images": True,
                },
            )
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

        if path == "/v1/images/generations":
            try:
                payload = json.loads(body.decode("utf-8") or "{}")
            except Exception:
                payload = {}
            prompt = str(payload.get("prompt") or "")
            size = str(payload.get("size") or "768x768")
            try:
                w, h = [int(x) for x in size.lower().split("x", 1)]
            except Exception:
                w, h = 768, 768
            try:
                result = _generate_image(prompt, width=w, height=h)
                self._json(200, result)
            except Exception as e:
                self._json(500, {"error": {"message": str(e), "type": "image_error"}})
            return

        if path != "/v1/chat/completions":
            self._json(404, {"error": {"message": f"no route {path}"}})
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
            self._json(
                500,
                {"error": {"message": "build/web missing — run: flutter build web --release"}},
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
        f"HRTBRKR web → LLM {DEFAULT_UPSTREAM} model={DEFAULT_MODEL}  "
        f"images={'sd:'+SD_BASE if SD_BASE else 'pollinations'}",
        flush=True,
    )
    print(f"Open http://{args.host}:{args.port}", flush=True)
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()

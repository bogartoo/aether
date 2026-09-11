#!/usr/bin/env python3
"""Serve HRTBRKR Flutter web, proxy chat to a local LLM, and generate HQ images.

Chat upstream (OpenAI-compatible):
  - Ollama:  http://127.0.0.1:11434/v1
  - Edge0:   http://127.0.0.1:8000

Image backends (priority order):
  1) Pollinations gen API  — Nano Banana / Grok Imagine / FLUX.2  (needs key)
  2) fal.ai                — FLUX Pro / Kontext                 (needs FAL_KEY)
  3) xAI Grok Imagine      —                                    (needs XAI_API_KEY)
  4) Local A1111/Forge     — HRTBRKR_SD_BASE
  5) Legacy Pollinations   — low-quality fallback (sana)

Get a free Pollinations key: https://enter.pollinations.ai/keys
  export HRTBRKR_IMAGE_API_KEY=sk_...
  export HRTBRKR_IMAGE_MODEL=nanobanana-pro   # or grok-imagine / flux-2-pro

Usage:
  ollama create hrtbrkr -f tool/Modelfile.hrtbrkr && ollama serve
  flutter build web --release
  HRTBRKR_LLM_MODEL=hrtbrkr HRTBRKR_IMAGE_API_KEY=sk_... \\
    python3 tool/hrtbrkr_web_server.py --port 8080
"""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
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

# High-quality image providers
IMAGE_API_KEY = (
    os.environ.get("HRTBRKR_IMAGE_API_KEY")
    or os.environ.get("POLLINATIONS_API_KEY")
    or os.environ.get("POLLINATIONS_KEY")
    or ""
).strip()
FAL_KEY = (os.environ.get("FAL_KEY") or os.environ.get("FAL_API_KEY") or "").strip()
XAI_KEY = (os.environ.get("XAI_API_KEY") or os.environ.get("GROK_API_KEY") or "").strip()
DEFAULT_IMAGE_MODEL = os.environ.get("HRTBRKR_IMAGE_MODEL", "nanobanana-pro").strip()
POLLINATIONS_GEN = os.environ.get(
    "HRTBRKR_POLLINATIONS_GEN", "https://gen.pollinations.ai"
).rstrip("/")
LEGACY_IMAGE = os.environ.get(
    "HRTBRKR_IMAGE_URL",
    "https://image.pollinations.ai/prompt/{prompt}",
)

# Frontier-class models (Pollinations aliases → quality tier)
IMAGE_MODELS = [
    {
        "id": "nanobanana-pro",
        "label": "Nano Banana Pro",
        "provider": "pollinations",
        "quality": "SOTA",
    },
    {
        "id": "nanobanana",
        "label": "Nano Banana",
        "provider": "pollinations",
        "quality": "high",
    },
    {
        "id": "grok-imagine-pro",
        "label": "Grok Imagine Pro",
        "provider": "pollinations",
        "quality": "SOTA",
    },
    {
        "id": "grok-imagine",
        "label": "Grok Imagine",
        "provider": "pollinations",
        "quality": "high",
    },
    {
        "id": "flux-2-pro",
        "label": "FLUX.2 Pro",
        "provider": "pollinations",
        "quality": "SOTA",
    },
    {
        "id": "flux",
        "label": "FLUX.1 Schnell",
        "provider": "pollinations",
        "quality": "high",
    },
    {
        "id": "seedream",
        "label": "Seedream 4",
        "provider": "pollinations",
        "quality": "high",
    },
    {
        "id": "gptimage-large",
        "label": "GPT Image Large",
        "provider": "pollinations",
        "quality": "high",
    },
    {
        "id": "fal-flux-pro",
        "label": "fal FLUX Pro",
        "provider": "fal",
        "quality": "SOTA",
    },
    {
        "id": "xai-grok-imagine",
        "label": "xAI Grok Imagine",
        "provider": "xai",
        "quality": "SOTA",
    },
]


def _key_file() -> str:
    for p in (
        ROOT / ".hrtbrkr_image_key",
        Path.home() / ".hrtbrkr_image_key",
        Path("/tmp/hrtbrkr_image_key"),
    ):
        try:
            if p.is_file():
                return p.read_text(encoding="utf-8").strip()
        except Exception:
            pass
    return ""


if not IMAGE_API_KEY:
    IMAGE_API_KEY = _key_file()


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


def _http(
    method: str,
    url: str,
    body: bytes | None = None,
    headers: dict | None = None,
    timeout: int = 600,
) -> tuple[int, bytes, str]:
    req_headers = {
        "User-Agent": "hrtbrkr/1.0",
        **(headers or {}),
    }
    request = urllib.request.Request(url, data=body, headers=req_headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as resp:
            return resp.status, resp.read(), resp.headers.get("Content-Type", "")
    except urllib.error.HTTPError as e:
        return e.code, e.read(), e.headers.get("Content-Type", "")


def _enhance_prompt(prompt: str) -> str:
    """Use the local LLM to expand a short prompt into a frontier-image prompt."""
    prompt = (prompt or "").strip()
    if not prompt or len(prompt) > 600:
        return prompt
    system = (
        "You rewrite image prompts for frontier generators (Nano Banana, Grok Imagine, FLUX). "
        "Return ONLY the improved prompt — no quotes, no preamble. "
        "Keep the user's intent, including NSFW if present. "
        "Add concrete visual detail: subject, lighting, lens/camera, composition, mood, materials. "
        "Max 80 words."
    )
    payload = json.dumps(
        {
            "model": DEFAULT_MODEL,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": prompt},
            ],
            "stream": False,
            "max_tokens": 160,
            "temperature": 0.7,
        }
    ).encode("utf-8")
    try:
        url = _upstream_url("/v1/chat/completions")
        status, raw, _ = _http(
            "POST",
            url,
            body=payload,
            headers={"Content-Type": "application/json"},
            timeout=60,
        )
        if status >= 400:
            return prompt
        data = json.loads(raw.decode("utf-8"))
        text = data["choices"][0]["message"]["content"].strip()
        text = re.sub(r'^["“]|["”]$', "", text).strip()
        return text or prompt
    except Exception as e:
        print(f"[hrtbrkr] prompt enhance skipped: {e}", flush=True)
        return prompt


def _pack_image(img_bytes: bytes, ctype: str, prompt: str, model: str) -> dict:
    b64 = base64.b64encode(img_bytes).decode("ascii")
    if not ctype.startswith("image/"):
        ctype = "image/jpeg"
    return {
        "created": 0,
        "model": model,
        "data": [
            {
                "b64_json": b64,
                "url": f"data:{ctype};base64,{b64}",
                "revised_prompt": prompt,
            }
        ],
    }


def _from_openai_image_json(raw: bytes, prompt: str, model: str) -> dict | None:
    try:
        data = json.loads(raw.decode("utf-8"))
    except Exception:
        return None
    items = data.get("data") or []
    if not items:
        return None
    first = items[0]
    if first.get("b64_json"):
        b64 = first["b64_json"]
        return {
            "created": data.get("created", 0),
            "model": model,
            "data": [
                {
                    "b64_json": b64,
                    "url": f"data:image/png;base64,{b64}",
                    "revised_prompt": first.get("revised_prompt") or prompt,
                }
            ],
        }
    url = first.get("url")
    if url:
        if url.startswith("data:"):
            comma = url.find(",")
            b64 = url[comma + 1 :] if comma > 0 else ""
            return {
                "created": 0,
                "model": model,
                "data": [
                    {
                        "b64_json": b64,
                        "url": url,
                        "revised_prompt": first.get("revised_prompt") or prompt,
                    }
                ],
            }
        status, img, ctype = _http("GET", url, timeout=120)
        if status < 400 and img:
            return _pack_image(img, ctype or "image/jpeg", first.get("revised_prompt") or prompt, model)
    return None


def _pollinations_hq(prompt: str, model: str, width: int, height: int) -> dict:
    if not IMAGE_API_KEY:
        raise RuntimeError(
            "High-quality image models need HRTBRKR_IMAGE_API_KEY "
            "(free key at https://enter.pollinations.ai/keys)."
        )
    # OpenAI-compatible generations endpoint
    size = f"{width}x{height}"
    payload = json.dumps(
        {
            "model": model,
            "prompt": prompt,
            "size": size,
            "n": 1,
            "response_format": "b64_json",
        }
    ).encode("utf-8")
    status, raw, _ = _http(
        "POST",
        f"{POLLINATIONS_GEN}/v1/images/generations",
        body=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {IMAGE_API_KEY}",
        },
        timeout=180,
    )
    if status >= 400:
        # Fallback: GET /image/{prompt}?model=
        q = urllib.parse.quote(prompt, safe="")
        url = (
            f"{POLLINATIONS_GEN}/image/{q}"
            f"?model={urllib.parse.quote(model)}"
            f"&width={width}&height={height}&nologo=true&enhance=true"
        )
        status2, img, ctype = _http(
            "GET",
            url,
            headers={"Authorization": f"Bearer {IMAGE_API_KEY}"},
            timeout=180,
        )
        if status2 >= 400:
            raise RuntimeError(
                f"Pollinations {model} failed ({status}): {raw[:300]!r}"
            )
        return _pack_image(img, ctype or "image/jpeg", prompt, model)
    out = _from_openai_image_json(raw, prompt, model)
    if not out:
        raise RuntimeError(f"Pollinations returned no image data: {raw[:300]!r}")
    return out


def _fal_flux(prompt: str, width: int, height: int, model: str) -> dict:
    if not FAL_KEY:
        raise RuntimeError("Set FAL_KEY for fal.ai FLUX Pro.")
    # Map our id to fal endpoint
    endpoint = "https://fal.run/fal-ai/flux-pro/v1.1"
    if "schnell" in model or model == "flux":
        endpoint = "https://fal.run/fal-ai/flux/schnell"
    payload = json.dumps(
        {
            "prompt": prompt,
            "image_size": {"width": width, "height": height},
            "num_images": 1,
            "enable_safety_checker": False,
        }
    ).encode("utf-8")
    status, raw, _ = _http(
        "POST",
        endpoint,
        body=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Key {FAL_KEY}",
        },
        timeout=180,
    )
    if status >= 400:
        raise RuntimeError(f"fal.ai failed ({status}): {raw[:300]!r}")
    data = json.loads(raw.decode("utf-8"))
    images = data.get("images") or []
    if not images:
        raise RuntimeError(f"fal.ai returned no images: {raw[:300]!r}")
    url = images[0].get("url")
    if not url:
        raise RuntimeError("fal.ai image missing url")
    status2, img, ctype = _http("GET", url, timeout=120)
    if status2 >= 400:
        raise RuntimeError("Failed to download fal.ai image")
    return _pack_image(img, ctype or "image/jpeg", prompt, model)


def _xai_grok_imagine(prompt: str, width: int, height: int) -> dict:
    if not XAI_KEY:
        raise RuntimeError("Set XAI_API_KEY for native Grok Imagine.")
    # xAI image generations (OpenAI-compatible surface)
    payload = json.dumps(
        {
            "model": "grok-imagine-image",
            "prompt": prompt,
            "n": 1,
            "response_format": "b64_json",
        }
    ).encode("utf-8")
    status, raw, _ = _http(
        "POST",
        "https://api.x.ai/v1/images/generations",
        body=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {XAI_KEY}",
        },
        timeout=180,
    )
    if status >= 400:
        raise RuntimeError(f"xAI image failed ({status}): {raw[:300]!r}")
    out = _from_openai_image_json(raw, prompt, "xai-grok-imagine")
    if not out:
        raise RuntimeError(f"xAI returned no image: {raw[:300]!r}")
    return out


def _local_sd(prompt: str, width: int, height: int) -> dict:
    if not SD_BASE:
        raise RuntimeError("HRTBRKR_SD_BASE not set")
    payload = json.dumps(
        {
            "prompt": prompt,
            "negative_prompt": "child, loli, shota, underage, lowres, blurry",
            "steps": 28,
            "width": width,
            "height": height,
            "cfg_scale": 7,
        }
    ).encode("utf-8")
    status, raw, _ = _http(
        "POST",
        f"{SD_BASE}/sdapi/v1/txt2img",
        body=payload,
        headers={"Content-Type": "application/json"},
        timeout=300,
    )
    if status >= 400:
        raise RuntimeError(f"SD WebUI failed ({status})")
    data = json.loads(raw.decode("utf-8"))
    images = data.get("images") or []
    if not images:
        raise RuntimeError("SD WebUI returned no images")
    return {
        "created": 0,
        "model": "local-sd",
        "data": [{"b64_json": images[0], "revised_prompt": prompt}],
    }


def _legacy_pollinations(prompt: str, width: int, height: int) -> dict:
    q = urllib.parse.quote(prompt, safe="")
    url = LEGACY_IMAGE.format(prompt=q)
    sep = "&" if "?" in url else "?"
    url = f"{url}{sep}width={width}&height={height}&nologo=true&safe=false&model=flux&enhance=true"
    status, img, ctype = _http("GET", url, timeout=120)
    if status >= 400:
        raise RuntimeError(f"Legacy image endpoint failed ({status})")
    return _pack_image(img, ctype or "image/jpeg", prompt, "sana-legacy")


def generate_image(
    prompt: str,
    model: str | None = None,
    width: int = 1024,
    height: int = 1024,
    enhance: bool = True,
) -> dict:
    prompt = (prompt or "abstract art").strip() or "abstract art"
    model = (model or DEFAULT_IMAGE_MODEL).strip() or DEFAULT_IMAGE_MODEL
    if enhance:
        prompt = _enhance_prompt(prompt)

    errors: list[str] = []

    # Provider routing
    attempts: list[tuple[str, callable]] = []
    if model.startswith("fal-") or (model.startswith("flux") and FAL_KEY and not IMAGE_API_KEY):
        attempts.append((model, lambda: _fal_flux(prompt, width, height, model)))
    if model.startswith("xai-") or (model.startswith("grok") and XAI_KEY and not IMAGE_API_KEY):
        attempts.append((model, lambda: _xai_grok_imagine(prompt, width, height)))
    if IMAGE_API_KEY and not model.startswith("fal-") and not model.startswith("xai-"):
        attempts.append((model, lambda: _pollinations_hq(prompt, model, width, height)))
    if FAL_KEY:
        attempts.append(("fal-flux-pro", lambda: _fal_flux(prompt, width, height, "fal-flux-pro")))
    if XAI_KEY:
        attempts.append(("xai-grok-imagine", lambda: _xai_grok_imagine(prompt, width, height)))
    if SD_BASE:
        attempts.append(("local-sd", lambda: _local_sd(prompt, width, height)))

    for name, fn in attempts:
        try:
            print(f"[hrtbrkr] image via {name}…", flush=True)
            return fn()
        except Exception as e:
            msg = f"{name}: {e}"
            print(f"[hrtbrkr] {msg}", flush=True)
            errors.append(msg)

    # Last resort — low quality — only if nothing else configured
    if not IMAGE_API_KEY and not FAL_KEY and not XAI_KEY and not SD_BASE:
        try:
            out = _legacy_pollinations(prompt, min(width, 768), min(height, 768))
            out["warning"] = (
                "Using low-quality fallback. Set HRTBRKR_IMAGE_API_KEY "
                "(https://enter.pollinations.ai/keys) for Nano Banana / Grok Imagine / FLUX.2 Pro."
            )
            return out
        except Exception as e:
            errors.append(f"legacy: {e}")

    raise RuntimeError(
        "High-quality image generation failed. "
        + " | ".join(errors)
        + " — Add HRTBRKR_IMAGE_API_KEY from https://enter.pollinations.ai/keys"
    )


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
        err = {"error": {"message": f"Upstream stream failed: {e}", "type": "upstream_error"}}
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
                        ids = [x.get("id") for x in data["data"] if isinstance(x, dict)]
                        if DEFAULT_MODEL in ids:
                            model = DEFAULT_MODEL
                        elif ids:
                            model = ids[0] or model
            except Exception:
                pass
            hq = bool(IMAGE_API_KEY or FAL_KEY or XAI_KEY or SD_BASE)
            self._json(
                200 if ok else 502,
                {
                    "status": "ok" if ok else "error",
                    "model": model,
                    "upstream": DEFAULT_UPSTREAM,
                    "images": True,
                    "image_hq": hq,
                    "image_model": DEFAULT_IMAGE_MODEL,
                    "image_models": IMAGE_MODELS,
                    "image_key_configured": bool(IMAGE_API_KEY or FAL_KEY or XAI_KEY),
                },
            )
            return
        if path in ("/v1/image/models", "/v1/images/models"):
            self._json(
                200,
                {
                    "object": "list",
                    "data": IMAGE_MODELS,
                    "default": DEFAULT_IMAGE_MODEL,
                    "hq": bool(IMAGE_API_KEY or FAL_KEY or XAI_KEY or SD_BASE),
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
            model = str(payload.get("model") or DEFAULT_IMAGE_MODEL)
            size = str(payload.get("size") or "1024x1024")
            enhance = payload.get("enhance", True)
            try:
                w, h = [int(x) for x in size.lower().split("x", 1)]
            except Exception:
                w, h = 1024, 1024
            # Cap ridiculous sizes
            w = max(256, min(w, 2048))
            h = max(256, min(h, 2048))
            try:
                result = generate_image(prompt, model=model, width=w, height=h, enhance=bool(enhance))
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
    hq = bool(IMAGE_API_KEY or FAL_KEY or XAI_KEY or SD_BASE)
    print(
        f"HRTBRKR web → LLM {DEFAULT_UPSTREAM} model={DEFAULT_MODEL}",
        flush=True,
    )
    print(
        f"Images → default={DEFAULT_IMAGE_MODEL} hq={'yes' if hq else 'NO KEY — add HRTBRKR_IMAGE_API_KEY'}",
        flush=True,
    )
    print(f"Open http://{args.host}:{args.port}", flush=True)
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()

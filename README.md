# HRTBRKR

HRTBRKR — personal AI agent powered by a **real local LLM**. Flutter (Android / iOS / Windows / web). No Grok, no cloud API keys — chat goes to an OpenAI-compatible server on your machine.

Supported local backends:

| Backend | When | Command |
|---------|------|---------|
| **[Edge0](https://github.com/Edge0-AI/Edge0)** | Apple Silicon (MLX) — streaming MoE from the [announcement](https://x.com/samuelzengml/status/2097861839287927139) | `edge0 serve edge0-8b` → `:8000` |
| **[Ollama](https://ollama.com)** | Linux / Windows / Mac — any GGUF chat model | `ollama serve` + `ollama run llama3.2:3b` → `:11434` |

## Try the web UI (real model)

```bash
# 1) real weights
ollama serve
ollama pull llama3.2:3b

# 2) HRTBRKR web + proxy to Ollama
flutter build web --release
HRTBRKR_LLM_BASE=http://127.0.0.1:11434/v1 \
HRTBRKR_LLM_MODEL=llama3.2:3b \
  python3 tool/hrtbrkr_web_server.py --port 8080

# open http://127.0.0.1:8080 → Connect local LLM
```

Point the same server at Edge0 instead:

```bash
edge0 serve edge0-8b
HRTBRKR_LLM_BASE=http://127.0.0.1:8000 \
HRTBRKR_LLM_MODEL=edge0-8b \
  python3 tool/hrtbrkr_web_server.py --port 8080
```

## Run the Flutter app

```bash
flutter pub get
flutter run
```

Default desktop/mobile base URL is `http://127.0.0.1:8000` (Edge0). For Ollama, open **Server settings** and set:

```text
http://127.0.0.1:11434/v1
```

### Android emulator

Use `http://10.0.2.2:11434/v1` (Ollama) or `http://10.0.2.2:8000` (Edge0) to reach the host.

## Edge0 on Mac

```bash
# Edge0 checkout
python3.12 -m venv .venv && .venv/bin/pip install -e '.[dev,fetch]'
.venv/bin/python scripts/fetch_models.py --tier edge0-8b --target-dir models
export EDGE0_8B_MODEL=$PWD/models/edge0-8b
edge0 serve edge0-8b
```

Or: `./tool/edge0_serve.sh`

## Dev map

- Connect UI: `lib/screens/connect_screen.dart`
- Chat UI: `lib/screens/chat_screen.dart`
- LLM client: `lib/api/edge0_client.dart` (OpenAI-compatible)
- Web + proxy: `tool/hrtbrkr_web_server.py`
- State: `lib/state/hrtbrkr_controller.dart`

## TestFlight

See [`docs/TESTFLIGHT.md`](./docs/TESTFLIGHT.md). An iOS target is scaffolded (`ios/`), but a join link still requires your Apple Developer account + an Xcode archive upload.

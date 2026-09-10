# HRTBRKR

HRTBRKR — personal AI agent powered by **your own** [Edge0](https://github.com/Edge0-AI/Edge0) LLM. Flutter (Android / Windows / web). No Grok, no cloud API keys — chat goes to a local `edge0 serve` process over the OpenAI-compatible API.

## How it works

1. Install and run Edge0 on an Apple Silicon Mac (MLX backend today).
2. Open HRTBRKR and tap **Connect to Edge0**.
3. Chat — prompts stay on your machine.

Edge0 streams MoE experts from SSD (`edge0-8b` ~1 GB peak RAM, `edge0-35b` ~2.9 GB). See the [Edge0 announcement](https://x.com/samuelzengml/status/2097861839287927139) and [docs](https://edge0.ai/models/edge0-35b).

## Run Edge0 (Mac)

```bash
# in the Edge0 repo
python3.12 -m venv .venv && .venv/bin/pip install -e '.[dev,fetch]'
.venv/bin/python scripts/fetch_models.py --tier edge0-8b --target-dir models
export EDGE0_8B_MODEL=$PWD/models/edge0-8b
edge0 serve edge0-8b
# → http://127.0.0.1:8000  (OpenAI-compatible /v1/chat/completions)
```

Or use the helper in this repo:

```bash
./tool/edge0_serve.sh            # edge0-8b
./tool/edge0_serve.sh edge0-35b  # larger tier
```

## Run HRTBRKR

```bash
flutter pub get
flutter run                 # device / emulator / chrome
flutter build apk --release
```

### Android emulator note

`127.0.0.1` inside the emulator is the emulator itself. In **Server settings**, set the base URL to:

```text
http://10.0.2.2:8000
```

so traffic reaches Edge0 on your Mac host. On a physical phone, use your Mac’s LAN IP (and bind Edge0 with `--host 0.0.0.0` if needed).

## Platforms

| Surface | Notes |
|---------|--------|
| Flutter client | Android, Windows, web — talks to Edge0 over HTTP |
| Edge0 server | Apple Silicon + MLX today; CUDA backend is on Edge0’s roadmap |

## Dev map

- Connect UI: `lib/screens/connect_screen.dart`
- Chat UI: `lib/screens/chat_screen.dart`
- Edge0 client: `lib/api/edge0_client.dart` → `http://127.0.0.1:8000/v1/chat/completions`
- State: `lib/state/hrtbrkr_controller.dart`

## TestFlight

See [`docs/TESTFLIGHT.md`](./docs/TESTFLIGHT.md). An iOS target is scaffolded (`ios/`), but a join link still requires your Apple Developer account + an Xcode archive upload.

# Aether

Personal hybrid AI agent for Android (also iOS / Windows / macOS / Linux / Web). **Broken-heart brand.** Grok chat + **Grok Imagine** image generation.

## Test on Android (APK ready)

Download and sideload:

- **[`releases/aether.apk`](./releases/aether.apk)** — package `com.aether.app.aether` (v1.0.1, arm64-v8a)

1. Install the APK (allow unknown sources)
2. Open Aether → **Connect** → paste your key from [console.x.ai](https://console.x.ai)
3. Chat, or open **Imagine** / toggle image mode

## What's in this build

- Broken heart logo (launcher + in-app)
- Grok streaming chat via xAI API key (stored on-device)
- Imagine studio + in-chat image generation (`grok-imagine-image-2.0`)
- Provider switcher scaffold (Ollama / Claude / Gemini)

## Build from source

```bash
flutter pub get
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
cp build/app/outputs/flutter-apk/app-release.apk releases/aether.apk
```

## Other suite APKs

See [`releases/`](./releases/) for companion packages.

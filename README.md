# Aether

Aether — personal hybrid AI agent. Flutter (Android / iOS / Windows / macOS / Linux / Web). **Broken-heart brand.** Grok chat + **Grok Imagine image generation baked in**.

## What's in this build

- **Broken heart logo** as the in-app mark and Android / web launcher icons
- **Grok connect** via your xAI API key (stored locally with secure storage)
- **Streaming chat** against Grok models
- **Imagine** — dedicated studio + in-chat image mode (`/imagine …` or the image toggle)
- Provider switcher scaffold for Ollama / Claude / Gemini (Grok is live)

## Connect Grok

1. Create a key at [console.x.ai](https://console.x.ai)
2. Open Aether → tap the broken heart / Settings
3. Paste the key → **Save & connect**

## Imagine

- Tap the image icon in the composer to toggle Imagine mode, or open **Imagine studio** from the header
- Uses `grok-imagine-image-2.0` by default (changeable in Settings)

## Run

```bash
flutter pub get
flutter run -d chrome
# or
flutter run -d windows
flutter build apk --release
```

## Download APKs

Ready-to-install Android builds are in [`releases/`](./releases/) when published by the build pipeline.

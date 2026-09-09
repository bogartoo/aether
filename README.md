# Aether

Personal hybrid AI agent for Android (also Windows / web). **Broken-heart brand.** Sign in with **Grok** (SuperGrok / X Premium+) for subscription chat — or paste an `xai-` API key. Includes **Grok Imagine** image generation.

## Test on Android (APK ready)

Download and sideload **[`releases/aether.apk`](./releases/aether.apk)** — package `com.aether.app.aether` (v1.0.2, arm64-v8a).

1. Install the APK (allow unknown sources)
2. Open Aether → **Sign in with Grok** (or paste a key from [console.x.ai](https://console.x.ai))
3. Chat, toggle **Imagine**, or open the Imagine studio

## Sign in with Grok

1. Tap **Sign in with Grok**
2. Approve the device code at [accounts.x.ai](https://accounts.x.ai/oauth2/device)
3. Chat — tokens stay on-device and refresh automatically

Uses xAI’s public device-code OAuth client (same path as OpenCode / Hermes). No password is typed into Aether.

> Requires an active SuperGrok or X Premium+ subscription. If OAuth succeeds but chat/Imagine returns 403, use an API key from [console.x.ai](https://console.x.ai).

### Web note

Browsers cannot call `auth.x.ai` directly (CORS). For Flutter web locally:

```bash
python3 tool/oauth_cors_proxy.py
flutter run -d chrome
```

Android / Windows talk to xAI natively — no proxy needed.

## What's in this build

- Broken heart logo (launcher + in-app)
- Grok OAuth sign-in + API key fallback
- Streaming Grok chat
- Imagine studio + in-chat Imagine mode (`grok-imagine-image-2.0`)
- On-device credential storage

## Build from source

```bash
flutter pub get
flutter run
flutter build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk releases/aether.apk
```

## Dev notes

- OAuth: `lib/auth/grok_oauth.dart`
- Chat + Imagine API: `lib/api/grok_client.dart`
- Secure token store on mobile/desktop; SharedPreferences on web

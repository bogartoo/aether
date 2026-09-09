# Aether

Aether — personal + hybrid AI agent. Flutter (Android / iOS / Windows / web). Sign in with your **Grok** account (SuperGrok or X Premium+) for subscription-backed chat — or drop in an `xai-` API key.

## Sign in with Grok

1. Open Aether and tap **Sign in with Grok**.
2. Approve the device code at [accounts.x.ai](https://accounts.x.ai/oauth2/device) (the app opens this for you).
3. Chat — tokens stay on-device and refresh automatically.

This uses xAI’s public device-code OAuth client (same path as OpenCode / Hermes). No password is typed into Aether.

> Requires an active SuperGrok or X Premium+ subscription linked to the xAI account you approve. If OAuth succeeds but chat returns 403, use an API key from [console.x.ai](https://console.x.ai) as a fallback.

### Web note

Browsers cannot call `auth.x.ai` directly (CORS). For Flutter web locally:

```bash
python3 tool/oauth_cors_proxy.py
flutter run -d chrome
```

Android / Windows / iOS talk to xAI natively — no proxy needed.

## Download APKs

Ready-to-install Android builds are in [`releases/`](./releases/):

- [aether.apk](./releases/aether.apk)
- [xai-toolkit.apk](./releases/xai-toolkit.apk)
- [assetforge.apk](./releases/assetforge.apk)
- [devforge.apk](./releases/devforge.apk)

Rebuild `aether.apk` after pulling this branch to pick up Grok sign-in.

## Build from source

```bash
flutter pub get
flutter run                 # device / emulator / chrome
flutter build apk --release
```

## Dev notes

- OAuth: `lib/auth/grok_oauth.dart`
- Chat API: `lib/api/grok_client.dart` → `https://api.x.ai/v1/chat/completions`
- Secure token store on mobile/desktop; SharedPreferences on web

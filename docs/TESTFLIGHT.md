# TestFlight for HRTBRKR

A public TestFlight link **cannot be minted from this cloud agent**. It requires your Apple Developer Program membership, Xcode on a Mac, and App Store Connect.

This branch already scaffolds `ios/` with:

- Bundle ID: `com.hrtbrkr.app.hrtbrkr` (change in Xcode if you prefer)
- Display name: **HRTBRKR**
- Local networking ATS exception so the app can reach Edge0 on your LAN (`NSAllowsLocalNetworking`)

## Publish steps (on your Mac)

1. Install Xcode + sign in with your Apple ID (paid Developer Program).
2. From the repo:

```bash
flutter pub get
open ios/Runner.xcworkspace
```

3. In Xcode → **Signing & Capabilities**: pick your Team, confirm Bundle ID.
4. Select **Any iOS Device (arm64)** → **Product → Archive**.
5. **Distribute App → App Store Connect → Upload**.
6. [App Store Connect](https://appstoreconnect.apple.com) → your app → **TestFlight**.
7. After processing finishes, add Internal/External testers and enable **Public Link**.

You’ll get a URL like `https://testflight.apple.com/join/XXXXXXXX`.

## Notes

- Edge0 itself still runs on Apple Silicon Mac (MLX). The iOS app is the **client**; point **Server settings** at your Mac’s LAN IP (e.g. `http://192.168.x.x:8000`) with `edge0 serve … --host 0.0.0.0`.
- For a quicker Android share while TestFlight is pending: `flutter build apk --release`.

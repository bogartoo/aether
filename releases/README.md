# Release APKs

Installable Android packages (debug-signed release builds).

| File | App | Package ID |
|------|-----|------------|
| [aether.apk](./aether.apk) | HRTBRKR (legacy filename) | `com.aether.app.aether` |
| [xai-toolkit.apk](./xai-toolkit.apk) | xAI Toolkit | `com.xaitoolkit.app.xai_toolkit` |
| [assetforge.apk](./assetforge.apk) | AssetForge | `com.assetforge.app.assetforge` |
| [devforge.apk](./devforge.apk) | DevForge | `com.devforge.app.devforge` |

Rebuild after pulling this branch to pick up the HRTBRKR + Edge0 client:

```bash
flutter build apk --release
# optionally: cp build/app/outputs/flutter-apk/app-release.apk releases/hrtbrkr.apk
```

On your phone: download the APK → allow install from this source → open the file.

## TestFlight (iOS)

This repo does not yet ship an `ios/` target or App Store Connect credentials in CI. To publish a TestFlight build on your Mac:

1. `flutter create --platforms=ios .` (keeps existing platforms)
2. Open `ios/Runner.xcworkspace` in Xcode, set Team + Bundle ID (e.g. `com.hrtbrkr.app`)
3. Archive → Distribute App → App Store Connect
4. In [App Store Connect](https://appstoreconnect.apple.com) → TestFlight, add testers and copy the public link

A real TestFlight URL can only be created with your Apple Developer account after the first successful upload.

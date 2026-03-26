# Changa Flutter App — Setup Guide

## Step 1 — Copy files into your project

Unzip and copy the contents into your existing Flutter project:
```
mobile/changa/
├── lib/          ← replace entirely with this zip's lib/
├── pubspec.yaml  ← replace
├── analysis_options.yaml
├── flutter_native_splash.yaml
```

## Step 2 — Create asset folders

```bash
cd mobile/changa
mkdir -p assets/fonts assets/images assets/animations assets/icons
```

## Step 3 — Download fonts (free from fonts.google.com)

Download and place in `assets/fonts/`:

**Sora** — download all weights:
- Sora-Light.ttf
- Sora-Regular.ttf
- Sora-SemiBold.ttf
- Sora-Bold.ttf
- Sora-ExtraBold.ttf

**DM Sans** — download:
- DMSans-Regular.ttf
- DMSans-Medium.ttf
- DMSans-Bold.ttf

Or from Google Fonts CLI:
```bash
# Easy alternative: use google_fonts package (already in pubspec)
# The fonts load from network automatically in debug mode
# For release, download manually as above
```

## Step 4 — Set your backend URL

Open `lib/core/constants/api_constants.dart`:

```dart
// Android emulator
static const String baseUrl = 'http://10.0.2.2:8000';

// Physical Android device (find your IP: ifconfig | grep inet)
static const String baseUrl = 'http://192.168.X.X:8000';

// Production
static const String baseUrl = 'https://api.changa.co.ke';
```

## Step 5 — Install dependencies and run

```bash
cd mobile/changa
flutter pub get
flutter run
```

## Step 6 — Native splash (optional, run once)

```bash
dart run flutter_native_splash:create
```

## Step 7 — Fix cleartext HTTP (Android emulator only)

In `android/app/src/main/AndroidManifest.xml`, inside `<application>`:
```xml
android:usesCleartextTraffic="true"
```
Remove this for production — use HTTPS instead.

## Troubleshooting

**"Connection refused" on emulator**
→ Use `http://10.0.2.2:8000` not `localhost`

**Fonts not loading**
→ File names in `pubspec.yaml` must exactly match `.ttf` files in `assets/fonts/`

**Build fails with "asset not found"**
→ Run `flutter clean && flutter pub get`

**"MissingPluginException" for flutter_secure_storage**
→ In `android/app/build.gradle`, add `multiDexEnabled true` under `defaultConfig`

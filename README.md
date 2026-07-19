# Life Stations 3.0.0+3

A local-first Flutter marketplace connecting demand and supply across independent
domains. **All five stations are live:** Marriage, Jobs, Rooms, Bikes, and Home Help.

Browse freely, create profiles with minimal typing, express mutual interest, verify
by phone when connecting, and open WhatsApp/Telegram only when privacy rules allow.
Public deep links at `/c/{slug}` expose only redacted presentation data.

## Run locally

Requirements: Flutter 3.44+ / Dart 3.12+, Android SDK for mobile, Node 20 for Functions.

```bash
flutter pub get
flutter run -d chrome
```

The first frame does not depend on Firebase. It uses fictional bundled cards.
Configure Firebase with `flutterfire configure` for your own project; never commit
service accounts or signing secrets.

```bash
flutter build web --release \
  --dart-define=RECAPTCHA_V3_SITE_KEY=YOUR_RESTRICTED_KEY \
  --dart-define=VISION_API_KEY=YOUR_RESTRICTED_KEY \
  --dart-define=SHARE_ORIGIN=https://your.host
```

## Checks

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
cd firebase/scripts && npm install && npm run validate:333
node --check ../functions/index.js
```

See `PARITY_MATRIX.md` and `PRODUCTION_READINESS.md` for gap status and release steps.

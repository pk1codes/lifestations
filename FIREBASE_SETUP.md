# Connecting to Firebase & Git
# Hey from nick

The app runs fully local-first with bundled seeds. Everything below is what makes it
talk to a real Firebase backend once you have credentials. Nothing here contains
secrets — real credential files are git-ignored.

## 1. Prerequisites

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
```

## 2. Generate app credentials (recommended path)

From the repo root, with your project id:

```bash
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID \
  --out=lib/firebase/firebase_options.dart \
  --platforms=android,ios,web
```

This overwrites the placeholder `lib/firebase/firebase_options.dart` and writes the
native config files:

- `android/app/google-services.json`  (git-ignored)
- `ios/Runner/GoogleService-Info.plist` (git-ignored — also add it to the Runner
  target in Xcode)

Templates are provided as `*.example` next to each expected location.

Once `android/app/google-services.json` exists, the Google Services and Crashlytics
Gradle plugins auto-apply (see `android/app/build.gradle.kts`). No build breakage
before then.

## 3. Runtime dart-defines

Copy `.env.example` to `.env` and pass the values you need:

```bash
flutter run \
  --dart-define=RECAPTCHA_V3_SITE_KEY=... \
  --dart-define=VISION_API_KEY=... \
  --dart-define=SHARE_ORIGIN=https://YOUR_FIREBASE_PROJECT_ID.web.app
```

- `RECAPTCHA_V3_SITE_KEY` — App Check on web.
- `VISION_API_KEY` — SafeSearch moderation (disabled when empty).
- `SHARE_ORIGIN` — origin used to build `/c/{slug}` deep-share links.

The client is defensive: if Firebase init fails, it falls back to local seeds.

## 4. Backend project (rules, functions, indexes, hosting)

Deploy config lives in `firebase/`. Set your project id in `firebase/.firebaserc`,
then from `firebase/`:

```bash
cd firebase
firebase use YOUR_FIREBASE_PROJECT_ID
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage,functions,hosting
```

Web hosting expects the Flutter web build copied into `firebase/public/`:

```bash
flutter build web --release \
  --dart-define=SHARE_ORIGIN=https://YOUR_FIREBASE_PROJECT_ID.web.app
rm -rf firebase/public && cp -r build/web firebase/public
```

## 5. Enable Firebase services in the console

- Authentication → Phone (used for contact unlock / OTP).
- Firestore, Storage, Cloud Functions, Cloud Messaging.
- App Check (Play Integrity on Android, App Attest on iOS, reCAPTCHA v3 on web).
- Cloud Vision API (only if using SafeSearch moderation).

## 6. Release signing (Android)

Copy `android/key.properties.example` to `android/key.properties`, point it at your
keystore (kept outside the repo), then `flutter build appbundle --release`. Without
`key.properties` the release build stays unsigned rather than using debug keys.

## 7. Git

The repo ships with a comprehensive `.gitignore` that excludes all real credential
files (`google-services.json`, `GoogleService-Info.plist`, `.env`, `*.jks`,
`key.properties`, service-account JSON, `.firebase/` cache). Only the `*.example`
templates and the placeholder `firebase_options.dart` are tracked.

```bash
git remote add origin YOUR_GIT_REMOTE_URL
git push -u origin main
```

## What stays external

Firebase project + credentials, App Check / Vision keys, Play product setup,
signing secrets, and authorized deploys are human actions. See `PARITY_MATRIX.md`
and `PRODUCTION_READINESS.md` for the full status.

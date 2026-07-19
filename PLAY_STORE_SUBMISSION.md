# Play Store submission — Life Stations

Everything needed to upload the app for internal testing and, later, production.

## 1. The build

- **App bundle:** `build/app/outputs/bundle/release/app-release.aab` (signed, ready to upload)
- **App name (Play listing):** `Life Stations`
- **Package name / application ID:** `com.lifestations.app` (do not change after first create)
- **Version:** `3.0.0` (versionCode `3`) — bump `version:` in `pubspec.yaml` for each new upload
- **Min SDK:** 23 (Android 6.0) · **Target SDK:** Flutter default (current)
- **Firebase project:** `aaaa-4eee0`

Rebuild command:

```bash
flutter build appbundle --release \
  --dart-define=SHARE_ORIGIN=https://aaaa-4eee0.web.app \
  --dart-define=RECAPTCHA_V3_SITE_KEY=<web reCAPTCHA site key from .env.local>
```

## 2. Signing (upload key)

- Keystore: `android/upload-keystore.jks` (git-ignored — **back this up**)
- Credentials: `android/key.properties` (git-ignored)
- Upload key SHA-256:
  `8C:16:F3:55:8C:AA:F3:AE:60:81:BA:13:6C:CA:4E:61:99:88:EA:71:F9:B3:11:BB:AE:18:8B:41:09:2D:62:0B`

Losing this keystore means you can't push updates, so store the `.jks` and its password
in a password manager.

## 3. Required policy URLs (live, HTTPS)

| Play Console field | URL |
|---|---|
| Privacy policy (Store listing + Data safety) | https://aaaa-4eee0.web.app/legal/privacy.html |
| Account/data deletion (Data safety) | https://aaaa-4eee0.web.app/legal/delete-account.html |
| Terms (optional) | https://aaaa-4eee0.web.app/legal/terms.html |

In-app: **Me → Settings & safety → Privacy policy / Data & account deletion / Community terms.**

## 4. Store listing graphics (`store_assets/`)

| Asset | File | Size |
|---|---|---|
| App icon (hi-res) | `store_assets/icon_512.png` | 512×512 |
| Feature graphic | `store_assets/feature_graphic_1024x500.png` | 1024×500 |
| Phone screenshot 1 | `store_assets/screenshot_1_discover.png` | 1080×1920 |
| Phone screenshot 2 | `store_assets/screenshot_2_sphere.png` | 1080×1920 |

## 5. Suggested listing copy

- **Title:** Life Stations
- **Short description:** One account, five life domains — Marriage, Jobs, Rooms, Bikes, Home Help.
- **Full description:** Discover people and services on a privacy-first radio dial. Publish redacted cards per domain, keep your contact private until there's mutual interest, and tune between domains with a 3D station picker. Contact is shared only after a verified phone session and mutual interest.

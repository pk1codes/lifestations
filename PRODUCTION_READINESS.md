# Production readiness

## Honest current state

This repository implements a working multi-domain client with local seeds, privacy-safe
deep sharing, typed domain forms with listing publish/sync, identity/OTP, likes/contact
gating, blocks/reports, media upload hooks, trust/refresh/boost helpers, FCM best-effort,
and Firebase rules/functions. It is **not** a finished production deployment: a real
Firebase project, restricted API keys, Play signing, and authorized deploys are still
required (see External actions). See `PARITY_MATRIX.md` for section-by-section status.

## Product override

All five domains are **enabled** in the radio tuner (Marriage, Jobs, Rooms, Bikes,
Home Help). Foundations and discovery feeds are available for each.

## Security boundaries

- Public share cards use an allowlisted schema — no name, displayName, bio, phone,
  WhatsApp, Telegram, RC/insurance URLs.
- Contact unlock requires non-anonymous phone-verified session + same-domain mutual likes
  (client + callable; rules prefer same-domain checks).
- Image flags / reports are create-only for clients.
- Vision and App Check keys come from dart-defines only.
- Demo inventory is synthetic; release clients must not invent private contacts.

## Proven locally

Re-run and record after each closure pass:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
cd firebase/scripts && npm install && npm run validate:333
node --check ../functions/index.js
```

## External actions

1. `flutterfire configure` + fill `lib/firebase/firebase_options.dart`
2. Restrict App Check / Vision keys
3. Phone auth, FCM/APNs, Play product `flut_boost_week`, optional Slack webhook
4. Production Android keystore in CI
5. Hosting hostname for App Links / Universal Links association files
6. Authorized Firebase deploy
7. Legal review of `web/legal/`

# Backend / Firebase production readiness

**Scope:** operational Firebase files only (rules, indexes, functions, scripts).  
**Date:** 2026-07-19  
**Deploy status:** not deployed (no credentials used).

Historical project name (documentation only): `marriage-71efc`.  
Active placeholder in `.firebaserc`: `YOUR_FIREBASE_PROJECT_ID`.

---

## Files owned by this track

| Path | Role |
|------|------|
| `firebase/firestore.rules` | Canonical Firestore security |
| `firebase/storage.rules` | Canonical Storage security |
| `firebase/firestore.indexes.json` | Composite discovery indexes |
| `firebase/firebase.json` | CLI deploy config (rules/indexes/storage/functions/hosting) |
| `firebase/.firebaserc` | Project selection placeholder |
| `firebase/web_config.json` | Admin/script project placeholders |
| `firebase/functions/` | Node 20 Cloud Functions (4 required) |
| `firebase/scripts/` | validate:333, safe seed, vault seed, bike URL cleanup, proofs |
| `firebase.json` (root) | FlutterFire metadata placeholders only |
| `test/firebase_rules_proof_test.dart` | Rules-source Flutter proofs |

---

## Security invariants encoded

- Public discovery profiles: empty WhatsApp/Telegram (`noPublicContact`)
- Contact vault unlock: non-anonymous **and same-domain mutual like**
- Offers: no top-level contact; attributes ban `whatsappNumber`, `telegramHandle`, `phone`, `rcUrl`, `insuranceUrl`
- Public cards: no name / displayName / bio / phone / WhatsApp / Telegram
- Like snapshots: no contact fields
- `image_flags` / `reports`: create-only, client unreadable
- `rate_limits`: owner-scoped, hits capped at 10
- Storage: ≤5 MiB; WebP/JPEG/PNG; RC/insurance owner-only read; verify_staging owner-only

---

## Local verification (no deploy)

```bash
node --check firebase/functions/index.js
cd firebase/scripts && npm install && npm run prove:backend
# After initial_seeds/ exists:
npm run validate:333
cd ../.. && flutter test test/firebase_rules_proof_test.dart
```

---

## Authorized deploy only (do not run without human approval)

```bash
# 1. Fill placeholders in firebase/.firebaserc and firebase/web_config.json
cd firebase
npm --prefix functions ci
firebase deploy --only firestore:rules,firestore:indexes,storage,functions

# 2. After Flutter web release build (other agent):
# rsync -a --delete build/web/ firebase/public/
# firebase deploy --only hosting
```

Optional legacy bike URL strip (requires `GOOGLE_APPLICATION_CREDENTIALS` outside repo):

```bash
cd firebase/scripts
npm run cleanup:bike-docs
```

Safe seed (empty public contact; vault-only demo contacts):

```bash
cd firebase/scripts
npm run seed:safe
npm run seed:vaults
```

Rotate any Admin SDK key that was ever committed or shared.

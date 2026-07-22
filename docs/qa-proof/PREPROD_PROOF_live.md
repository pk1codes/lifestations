# Pre-production QA proof report

- **Finished:** 2026-07-22 (UTC+3)
- **Repo:** `/home/gw/Desktop/a2`
- **Version:** `3.0.36+39` (as in `pubspec.yaml` at run time)
- **Runner:** user `gw` (non-root Flutter)
- **Plan:** `docs/PREPROD_QA_PLAN.md`

## Verdict

**ALL GATES GREEN** after fix loop. Ready for Hosting/Play upload from a gate perspective.

| Gate | Check | Result |
|------|--------|--------|
| G1 | `dart format --set-exit-if-changed lib test` | **PASS** (after format fix) |
| G2 | `flutter analyze` | **PASS** (after 3 lint fixes) |
| G3 | `flutter test --concurrency=1` | **PASS** — 174 tests |
| G4 | `npm run prove:backend` | **PASS** |
| G5 | `npm run validate:333` | **PASS** — 135 images |
| G6 | `node --check functions/index.js` | **PASS** |
| G7 | `public_cards_rules_contract.test.cjs` | **PASS** |
| G8 | `flutter build web --release` | **PASS** → `build/web` |
| G9 | `flutter build appbundle --release` | **PASS** → `app-release.aab` (~122 MB) |

---

## Errors found (every one) — proof & fix

### E1 — Format drift (G1 failed, exit 1)

**Proof:** First gate run reformatted **34 files** (e.g. `lib/widgets/tap_feedback.dart`, dial/OTP/likes tests). With `--set-exit-if-changed`, that is a fail.

**Fix:** Applied `dart format lib test` (including `dial_code_phone_field.dart` after later edits).

**Retest:** G1 exit **0** — `Formatted 124 files (0 changed)`.

---

### E2 — Analyzer issues (G2 failed, exit 1)

**Proof (exact analyzer lines):**

1. `lib/screens/home_shell.dart:485` — `curly_braces_in_flow_control_structures`  
   `if (mutual && context.mounted) _showMatch(...)` without braces.
2. `lib/state/app_stores.dart:146` — `type_init_formals`  
   `DiscoveryStore(this.domain, {DiscoveryFeedCache? this._feedCache})` needless type.
3. `lib/widgets/forms/dial_code_phone_field.dart:49` — `deprecated_member_use`  
   `DropdownButtonFormField.value` deprecated; use `initialValue`.

**Fix:**

1. Wrapped body in `{ }`.
2. Changed to `{this._feedCache}`.
3. Switched to `initialValue: dial` + `ValueKey('dial_code_${dial.digits}')`; updated `test/dial_code_phone_field_test.dart` finders.

**Retest:** G2 — **No issues found.** G3 — **174** tests passed.

---

### E3 — (Informational, not a gate fail) Kotlin Gradle Plugin warning on G9

**Proof:** Gradle/Flutter printed:

> Future versions of Flutter will fail to build if your app uses plugins that apply KGP…  
> plugins: cloud_functions, firebase_*, flutter_image_compress_common, google_mlkit_*, share_plus

**Fix:** None required for this release (build succeeded). Track plugin upgrades before a future Flutter breaking change.

**Retest:** G9 still **PASS** — AAB produced.

---

### Environment note (tooling, not product)

Initial attempts as `root` in sandbox failed Flutter with `engine.stamp` permission denied. Re-ran as user `gw` with Flutter on `PATH`. Not an app defect.

---

## Gate evidence (tails)

### G3 Tests
```
00:41 +174: All tests passed!
```

### G4 Backend
```
firestoreRulesBytes: 21008,
storageRulesBytes: 3209,
indexes: 17,
functions: [onReportCreated, onImageFlagCreated, checkFeedThrottle,
  onInboundLikeCreated, unlockContact, deleteAccount]
```

### G5 Seeds
```
Sharp 3×3×3 bundle OK: { images: 135, miB: '41.95' }
```

### G7 Rules contract
```
public_cards_rules_contract OK
```

### G8 / G9 artifacts
```
✓ Built build/web
✓ Built build/app/outputs/bundle/release/app-release.aab (121.7MB)
```

---

## What this does / does not cover

**Covered (automated, professional pre-prod):** format, static analysis, full unit/widget suite, backend invariants, seed integrity, Functions syntax, public-card rules contract, web + Android release compiles.

**Not covered here (manual / console / device):** real Firebase Phone OTP on device, Play Integrity / App Check in production, Play Console listing, SMS region policy, multi-device soak, performance on low-end Android, accessibility review.

Say **publish** to ship the web build to Hosting if desired.

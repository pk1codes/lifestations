# Phase 0 — Test inventory & gap map (Agent QA)

**Commit:** `abe95a9` · **Version:** `3.0.66+70` · **Suite size:** 76 `*_test.dart` files

## Coverage by flow

| Flow | Status | Evidence |
|------|--------|----------|
| Shell / domain switch | Covered | `ui_matrix_smoke_test`, `domain_switcher_test`, `domain_tile_picker_test` |
| Account save / cascade | Covered | `account_identity_cascade_test`, `account_phone_verify_test` |
| Account refresh metadata | Covered | `account_identity_refresh_test` (merge + phone-only prefs) |
| Sign out UI | Covered | `settings_sign_out_test` |
| OTP / phone gate | Covered | `otp_*`, `account_otp_gate_test`, `me_verify_phone_row_test` |
| Likes / Match / accept | Covered | `match_section_test`, `liked_me_two_block_test`, `likes_*`, `like_back_*` |
| Contact / WA gates | Covered | `whatsapp_*`, `contact_*`, `privacy_contract_test` |
| Kuwait Jobs | Covered | `kuwait_jobs_domain_test`, `position_picker`, `default_domain` |
| Jobs / Marriage | Covered | `jobs_*`, `marriage_create_cascade_test`, `workflow_contract_test` |
| Rooms / Bikes / Home Help | Partial | `workflow_contract_test`, `domain_forms_contract`, `domain_save_wiring` — thinner vs KJ/Jobs |
| Media / CDN | Covered | `media_*`, `photo_*` |
| Share redaction | Covered | `share_*`, `public_share_*`, `privacy_contract_test` |
| Security rules contracts | Covered | `firebase_rules_proof_test`, `security_checklist_contract_test` |
| Throttle / App Check copy | Partial | Source asserts no “Install from Play”; **no** unit that simulates `failed-precondition` bypass |

## Recent-bug gap table

| Bug | Covered? | Action |
|-----|----------|--------|
| Name vanishes; photo/posts survive | Yes | Keep `account_identity_refresh_test`; extend matrix if holes |
| Web Save “App verification / Play” | Partial | Add explicit App Check bypass contract + keep source assert |
| Sign out extra subtitle | Partial | Assert **absence** of posts/phone restore copy in settings test |
| Kuwait Jobs multi-position | Yes | Existing KJ tests |
| Match / like-back / unlock | Yes | Existing likes/match/privacy tests |

## Doc drift (security plan)

[`docs/qa-proof/SECURITY_TEST_PLAN_AND_PROOF.md`](SECURITY_TEST_PLAN_AND_PROOF.md) still claims:
- throttles have `enforceAppCheck: true` (**DONE** / inventory)
- client fail-closed gates on App Check for throttles

**Code truth:** unlock/delete enforce App Check; `claimActionThrottle` / `checkFeedThrottle` are auth + caps only; client bypasses App Check infrastructure failures on throttles.

→ Phase 3 B5: sync security doc.

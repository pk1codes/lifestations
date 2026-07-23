# Life Stations — Professional Security Test Plan & Proof Log

**Project:** `aaaa-4eee0` · Package `com.lifestations.app`  
**Repo commit at baseline:** `b507fdf` (Share icons.)  
**Baseline proof UTC:** `2026-07-23T09:38:43Z`  
**Audience:** engineering + release owners  
**Goal:** prove frontend, backend, rate limits, and bot/abuse resistance before each Play/Hosting ship.

---

## 0. Threat model (what we defend against)

| Actor | Goal | Primary surfaces |
|-------|------|------------------|
| Scripted bot / scraper | Mass-read listings, harvest photos, spam posts | Anonymous/signed-in Firestore reads, Storage CDN, Hosting `/c/*`, `serveMedia` |
| Credential-stuff / OTP abuse | Burn SMS quota, take over numbers | Firebase Phone Auth, `otp_trackers`, client OTP UI |
| Mutual-like bypass | Steal WhatsApp/Telegram without consent | `unlockContact`, vault `users/*/private/contact`, likes trees |
| Malicious client (rooted / patched APK / web console) | Write forbidden fields, reset throttles, escalate | Firestore/Storage rules, callable App Check |
| Share-link snooper | Extract PII from public cards | `domains/*/public_cards/*`, `PublicShareCard` allowlist |
| Upload abuse | NSFW / oversized / path traversal media | Storage rules, Vision (when keyed), client scanners |
| Account wipe / DoS | Delete others’ data or flood functions | `deleteAccount`, rate-limit callables, Auth identity |

**Trust boundary:** anything in the Flutter client is untrusted. Server truth = Auth token claims + Firestore/Storage rules + Cloud Functions Admin SDK. Local prefs (`phoneVerified`, throttles) are UX only.

---

## 1. Security control inventory (as shipped)

| Layer | Control | Location | Enforced? |
|-------|---------|----------|-----------|
| Auth | Anonymous → phone link / sign-in | `otp_sheet.dart`, `firebase_bootstrap.dart` | Yes (Auth) |
| Auth | Phone required for unlock | `unlockContact` checks `phone_number`, non-anonymous | Yes |
| App Check | Play Integrity / reCAPTCHA v3 | `firebase_bootstrap.dart` | Client on; callables: unlock, delete, both throttles |
| Firestore | Domain allowlist, listing schema bans contact | `firestore.rules` | Yes |
| Firestore | Contact vault owner-read only | `users/{uid}/private/{docId}` | Yes |
| Firestore | OTP tracker 60s update gate | `otp_trackers` | Best-effort (client fail-open) |
| Firestore | `rate_limits/{uid}` | owner read; create/update/delete denied (Functions Admin) | Yes |
| Storage | Auth write, 5 MiB, MIME, path slots | `storage.rules` | Yes |
| Storage | Public read for listing photos | intentional CDN | Accept risk |
| Functions | `claimActionThrottle`, `checkFeedThrottle` | `functions/index.js` | App Check + server caps; release client fail-closed |
| Functions | `unlockContact` mutual + App Check | callable | Yes |
| Client | Share allowlist / blur CTA | `public_share_card.dart`, share screen | Yes |
| Client | No demo feed in release | `feature_flags.dart` | Yes |
| Client | TextSafety / Vision optional | moderation + Vision key | Partial |
| Hosting | App Links `assetlinks.json` (Play + upload SHA) | `web/.well-known/assetlinks.json` | Deployed |

---

## 2. Test program (professional grade)

Execute in order. Each job has **method**, **pass criteria**, and **proof artifact**. Mark jobs `PASS` / `FAIL` / `BLOCKED` in §8.

### Phase A — Automated contract (CI / every commit)

| ID | Job | Method | Pass criteria | Proof |
|----|-----|--------|---------------|-------|
| A1 | Security checklist contracts | `flutter test test/security_checklist_contract_test.dart` | All green | §8 baseline |
| A2 | Firestore/Storage/Functions source proofs | `flutter test test/firebase_rules_proof_test.dart` | All green; no `request.app` falsely claimed | §8 |
| A3 | Privacy + unlock contracts | `flutter test test/privacy_contract_test.dart` | Mutual + phoneVerified required | §8 |
| A4 | Share redaction / allowlist | `share_redaction_test`, `share_public_card_fields_test`, `public_share_card_model_test` | No PII keys; forbidden rejected | §8 |
| A5 | OTP / contact gates | `account_otp_gate_test`, `otp_*`, `contact_*` | Cooldown + verify path | §8 |
| A6 | Throttle + no-demo release | `media_trust_throttle_test`, `no_demo_feed_release_test` | 10/30s feed lock; demos stripped | §8 |
| A7 | Full suite gate | `flutter test --concurrency=1` | 0 failures | Record count + commit |
| A8 | Static analyze | `dart analyze` / `flutter analyze` | No errors | Log |
| A9 | Functions syntax | `node --check firebase/functions/index.js` | Exit 0 | Log |

### Phase B — Rules emulator / live rules abuse (backend truth)

Use Firebase Emulator Suite **or** a throwaway project. Prefer Admin + unauthenticated / anonymous / phone-verified clients.

| ID | Job | Attack script | Pass criteria | Proof |
|----|-----|---------------|---------------|-------|
| B1 | Anonymous cannot write peer vault | Anon UID writes `users/{victim}/private/contact` | `PERMISSION_DENIED` | Rules test log / screenshot |
| B2 | Signed-in cannot read peer vault | User A gets `users/B/private/contact` | Denied | Log |
| B3 | Listing cannot embed phone/WhatsApp | Create offer/profile with contact attrs | Denied by `validOffer` / `validDiscoveryListing` | Log |
| B4 | Public card rejects forbidden keys | Write `name`/`bio`/`phone` on `public_cards` | Denied | Log |
| B5 | Public card world-readable only allowlisted fields | Unauth GET card; inspect JSON | Only allowlist keys | JSON dump |
| B6 | Like inbound forgery | User A writes inbound like as if from B without being B | Denied except legitimate liker create | Log |
| B7 | OTP tracker spam | Rapid updates `<60s` | Update denied | Log |
| B8 | `rate_limits` self-reset | Client sets `hits:0` then floods feed | **Document current behavior**; harden if client can bypass (`FAIL` until fixed) | Issue + repro |
| B9 | Storage path traversal / oversize | Upload `../../x`, 6 MiB, `text/plain` | Denied | Log |
| B10 | Storage docs privacy | Unauth read `media/.../docs/rc` | Denied | Log |
| B11 | Cross-domain unlock | Mutual in marriage, unlock jobs vault | Callable rejects | Function log |
| B12 | Anonymous unlock | Anon calls `unlockContact` | Rejected | Log |
| B13 | App Check missing on unlock | Call without App Check token | Rejected | Log |
| B14 | `deleteAccount` cannot target other UID | Attacker calls with victim intent | Only deletes caller | Log |
| B15 | `serveMedia` path escape | `?path=../` or non-image | 4xx | HTTP transcript |

### Phase C — Rate limits & bot / automation resistance

| ID | Job | Method | Pass criteria | Proof |
|----|-----|--------|---------------|-------|
| C1 | Feed flood | 20× `checkFeedThrottle` in 10s | ≥11th `resource-exhausted` | Callable logs |
| C2 | Like flood | 25 likes / 60s via `claimActionThrottle` | Cap at 20 | Logs |
| C3 | Report / image_flag flood | 10 creates / 10m | Cap at 6 | Logs |
| C4 | Post flood | 12 publishes / 30m | Cap at 8 | Logs |
| C5 | Client fail-open | Kill network mid-throttle then like | **Document**; ideally hard-fail in release | Video / note |
| C6 | OTP SMS burn | Script `verifyPhoneNumber` on many numbers | Firebase `too-many-requests` / quota; UI cooldown 60s | Auth console + UI |
| C7 | Hosting scrape | `curl`/`wget` loop on `/c/*` + discovery | Cards redacted; no vault; consider WAF/CDN rate later | HAR |
| C8 | Headless Chromium login farm | Puppeteer create N anons + posts | Throttles + rules hold; App Check on sensitive callables | Report |
| C9 | Replay stolen ID token | Replay after sign-out / revoke | Unlock/delete fail | Log |
| C10 | Play Integrity bypass attempt | Debug build vs release unlock | Debug must not ship; release requires Integrity | Build flavor check |

### Phase D — Frontend / UX security (human + instrumented)

| ID | Job | Steps | Pass criteria | Proof |
|----|-----|-------|---------------|-------|
| D1 | Like without phone | Fresh install → Like | OTP sheet; no like until Auth `phoneNumber` | Screen recording |
| D2 | WhatsApp without verify | Mutual → Open chat | OTP then share-number choice | Recording |
| D3 | Share card blur + CTA | Open `/c/{slug}` web | Blurred photo; no phone; Get the app → Play | Screenshot |
| D4 | Share from Browse | Share icon → link | URL `/c/{slug}`; redacted | Link + JSON |
| D5 | Me verify row | Unverified → verified | Auth phone persists across restart | Recording |
| D6 | Release empty feed | Release build, empty Firestore | No bundled demos | Screenshot |
| D7 | Deep link after Play install | Install from Play; open share URL | App opens card (App Links) | Device video |
| D8 | Web console tamper | DevTools set local `phoneVerified` | Unlock still blocked without Auth phone | Console + unlock error |
| D9 | XSS / HTML inject in listing fields | Post `<script>` / markdown | Escaped in UI; rules length/type limits | Screenshot |
| D10 | Clipboard / share sheet leak | Share listing | Message has URL only, no phone | Share sheet shot |

### Phase E — Secrets, supply chain, config

| ID | Job | Method | Pass criteria | Proof |
|----|-----|--------|---------------|-------|
| E1 | Git hygiene | `git status --ignored`; search for adminsdk / `.jks` / `.env.local` | Ignored, never committed | This doc §8 |
| E2 | dart-defines | Confirm release AAB built with `SHARE_ORIGIN` + `RECAPTCHA_V3_SITE_KEY` | No empty App Check on web | Build cmd log |
| E3 | Asset links | `curl https://aaaa-4eee0.web.app/.well-known/assetlinks.json` | Contains Play **deployment** SHA-256 | JSON dump |
| E4 | API key restrictions | GCP Console: Android package + SHA; HTTP referrer for web | Restricted | Console screenshot (internal) |
| E5 | Phone Auth regions | Firebase Auth → Settings | Only needed countries | Screenshot |
| E6 | Functions IAM | Only Cloud Functions SA can Admin | No public Admin key | Console |

### Phase F — Hardening backlog (must fix for “professional grade”)

| Pri | Gap | Why it matters | Recommended fix | Status |
|-----|-----|----------------|-----------------|--------|
| P0 | App Check not on Firestore/Storage | Stolen API key + anon = full browse/write within rules | Enable Enforcement after monitoring; add `request.app` when ready | OPEN |
| P0 | `rate_limits/{uid}` client-writable | Bot resets feed counters | Deny client writes; Functions-only Admin writes | **DONE** (rules deny client writes) |
| P0 | Action/Feed throttle fail-open | Offline/patched client skips caps | Release: fail closed on throttle errors for like/post/report | **DONE** (`failClosed` defaults to `kReleaseMode`) |
| P1 | `validIdentity` allows public `whatsappNumber` | Peer can read `users/{id}` if client regresses | Force empty contact fields in rules (`noPublicContact`) | OPEN |
| P1 | OTP tracker vs `serverTimestamp` mismatch | Server 60s gate may never apply | Align client write with `request.time` or loosen rules | OPEN |
| P1 | Throttles without App Check | Scripts call `claimActionThrottle` with stolen tokens | `enforceAppCheck: true` on throttle callables | **DONE** |
| P2 | World-readable Storage + `serveMedia` | Path leak = scrape | Signed URLs or auth-gated CDN for sensitive domains | OPEN |
| P2 | Weak TextSafety / optional Vision | NSFW/spam posts | Server moderation queue; require Vision in release | OPEN |
| P2 | No admin review API | Reports only Slack | Privileged review console + custom claims | OPEN |

---

## 3. Bot & exploit playbook (how to attack like an adversary)

1. **Anonymous scraper:** `signInAnonymously` → query all `domains/*/offers` → download Storage URLs.  
   *Expect:* listings without contact; photos public; throttles may fail-open — measure & harden.
2. **SMS burner:** rotate numbers through OTP.  
   *Expect:* Firebase quota + 60s UI; monitor Auth usage charts.
3. **Like-graph farming:** script mutual likes then `unlockContact`.  
   *Expect:* App Check + phone + mutual same-domain; without Integrity token → fail.
4. **Rules probe:** fuzz forbidden fields on every collection from §2 inventory.  
   *Expect:* `PERMISSION_DENIED` everywhere contact/PII is banned.
5. **Callable abuse:** replay / omit App Check / wrong args on `unlockContact`, `deleteAccount`, throttles.  
   *Expect:* reject except authenticated App-Checked caller on sensitive ops.
6. **Share enumeration:** brute `/c/{domain}_{token}`.  
   *Expect:* inactive/missing; redacted payloads; no phone digits.

---

## 4. Release gate (ship only if)

- [ ] Phase A all PASS on release commit  
- [ ] Phase B critical path B1–B7, B9–B14 PASS  
- [ ] Phase C C1–C4, C6, C10 PASS  
- [ ] Phase D D1–D8 PASS on Play-internal build  
- [ ] Phase E E1–E5 PASS  
- [ ] No open **P0** without written risk acceptance  
- [ ] Proof artifacts attached under `docs/qa-proof/` + this log updated  

---

## 5. Commands cheat-sheet

```bash
# A — contracts
flutter test \
  test/security_checklist_contract_test.dart \
  test/firebase_rules_proof_test.dart \
  test/privacy_contract_test.dart \
  test/share_redaction_test.dart \
  test/share_public_card_fields_test.dart \
  test/public_share_card_model_test.dart \
  test/media_trust_throttle_test.dart \
  test/no_demo_feed_release_test.dart \
  test/account_otp_gate_test.dart \
  test/otp_cooldown_ticker_test.dart \
  test/otp_firebase_phone_contract_test.dart \
  test/contact_share_choice_test.dart \
  test/share_link_router_test.dart

flutter analyze
node --check firebase/functions/index.js

# E3 — live assetlinks
curl -s https://aaaa-4eee0.web.app/.well-known/assetlinks.json

# Release AAB (App Check + share origin)
set -a && source .env.local && set +a
flutter build appbundle --release \
  --dart-define=SHARE_ORIGIN=https://aaaa-4eee0.web.app \
  --dart-define=RECAPTCHA_V3_SITE_KEY="$RECAPTCHA_V3_SITE_KEY"
```

---

## 6. Proof artifact standard

For every job: **date (UTC), operator, commit SHA, command or steps, raw output path or screenshot name, PASS/FAIL, notes**.  
Store under:

- `docs/qa-proof/SECURITY_TEST_PLAN_AND_PROOF.md` (this file)  
- `docs/qa-proof/security-runs/YYYYMMDD/` (logs, HAR, screenshots — git-lfs or local only if large)

Never commit Admin SDK JSON, keystores, or live phone numbers in proofs.

---

## 7. Roles

| Role | Owns |
|------|------|
| Eng | Phases A–B automation, P0/P1 fixes |
| QA / release | Phases C–D device matrix (Play install + web) |
| Ops | Phase E GCP/Firebase console restrictions |
| Owner | Risk acceptance for deferred P0 |

---

## 8. Proof log — jobs done

### Baseline automated suite (executed)

| Field | Value |
|-------|-------|
| UTC | `2026-07-23T09:38:43Z` |
| Commit | `b507fdf` |
| Command | Security contract suite (see §5) |
| Result | **63 tests passed** |
| Log | `/tmp/security_baseline_proof.txt` (local run) |
| Verdict | **PASS** for Phase A jobs A1–A6 on this commit |

### Secrets hygiene (executed)

| Check | Result |
|-------|--------|
| `.env.local` ignored | PASS |
| `android/key.properties` ignored | PASS |
| `android/upload-keystore.jks` ignored | PASS |
| `*adminsdk*` / `google-services.json` ignored | PASS |
| Commit `b507fdf` pushed without secrets | PASS |

### Live Hosting assetlinks (executed earlier same day)

| Check | Result |
|-------|--------|
| Play deployment SHA-256 present | PASS (`85:1E:BE:FF:…:47:BC`) |
| Upload key SHA-256 present | PASS (`8C:16:F3:55:…:62:0B`) |
| URL | https://aaaa-4eee0.web.app/.well-known/assetlinks.json |

### Clean-slate backend wipe (ops, earlier)

| Check | Result |
|-------|--------|
| Auth users wiped | 107 |
| Storage objects wiped | 261 |
| Firestore user/domain docs wiped | Yes |
| Rules/indexes/functions untouched | Yes |

### Still required (not yet proven this session)

| Phase | Status |
|-------|--------|
| B1–B15 live/emulator abuse | **NOT RUN** — schedule next |
| C1–C10 bot flood against production callables | **NOT RUN** — use staging |
| D1–D10 device UX security | **NOT RUN** — QA checklist |
| E4–E6 GCP console restrictions | **OWNER** — screenshots needed |
| P0 hardening items | **Partial** — rate_limits + fail-closed + throttle App Check **DONE**; Firestore/Storage App Check still OPEN |

### Bot top-3 patch proof (this session)

| Field | Value |
|-------|-------|
| UTC | `2026-07-23T13:40:00Z` (approx) |
| Changes | Deny client `rate_limits` writes; release fail-closed throttles; `enforceAppCheck` on `checkFeedThrottle` + `claimActionThrottle` |
| Deploy | Firestore rules + Functions on `aaaa-4eee0` |
| Contract tests | `firebase_rules_proof_test`, `security_checklist_contract_test`, `media_trust_throttle_test` |

---

## 9. Immediate next execution order

1. Emulator rules suite for B1–B7, B9–B10 (highest ROI).  
2. Staging callables C1–C4 + B11–B14 with App Check debug tokens.  
3. ~~Patch P0: deny client `rate_limits` writes; fail-closed throttles in release; App Check on throttle callables.~~ **DONE**  
4. Device D1–D8 on Play internal track (rebuild AAB after this patch).  
5. Remaining P0: App Check enforcement on Firestore/Storage (monitor → enforce).  
6. Re-run Phase A; attach new §8 entry; only then risk-accept remaining P2.

---

*Document owner: engineering. Update §8 after every security run.*

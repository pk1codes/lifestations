# Agent Prompt: Rebuild Flut Marriage from Scratch

Copy everything below this line into a capable coding agent with terminal, file-editing, Flutter, Node.js, and Firebase access.

---

You are the lead engineer responsible for rebuilding a production-oriented Flutter application from an empty directory. Work autonomously through implementation, tests, Firebase configuration, and release documentation. Do not stop after scaffolding or producing a plan: create the complete working repository and verify it.

## Mission

Build **Flut Marriage 3.0.0+3**, a low-friction, multi-domain Indian discovery marketplace whose primary live experiences are:

1. **Marriage** — intentional matchmaking.
2. **Jobs** — blue/grey-collar workers and hirers discovering each other.

Also implement the complete foundations, models, forms, stores, repositories, bundled inventory, and tests for:

3. **Rooms** — landlord room listings.
4. **Bikes** — hourly bike/scooter lending.
5. **Home Help** — workers offering help and households hiring.

Marriage and Jobs must be enabled in the domain tuner. Rooms, Bikes, and Home Help must remain disabled/“coming soon” in the public tuner at the present-state release boundary, even though their underlying implementation must exist and be testable.

The app’s promise is: **browse freely, create a profile with minimal typing, express mutual interest, verify by phone when connecting, and open WhatsApp/Telegram only when privacy rules allow it.**

## Non-negotiable working rules

- Start from an empty folder and create all source, configuration, tests, assets/manifests, Firebase rules, indexes, Cloud Functions, and deployment documentation.
- Use null-safe Dart and Material 3.
- Prefer small domain models, repositories, `ChangeNotifier` stores, and reusable widgets over monolithic screens.
- Keep the app useful if Firebase initialization, remote reads, analytics, notifications, billing, or moderation services fail.
- Never expose phone numbers, messaging handles, identity documents, vehicle documents, or document download URLs in public discovery documents.
- Do not add real people’s data or photos. Generate clearly synthetic seed content and images.
- Do not commit service-account files, `.env`, signing secrets, webhook URLs, or other credentials.
- Do not weaken tests or security rules to make checks pass.
- Complete each phase, run its checks, fix failures, and continue.

## Required stack and project setup

Create a Flutter project named `flut_marriage` with:

- Dart SDK constraint: `^3.12.2`
- Version: `3.0.0+3`
- Android and web as first-class release targets; keep standard iOS, Linux, macOS, and Windows scaffolding where Flutter generates it.
- State management: `provider`
- Local persistence: `shared_preferences`
- Backend: Firebase Core, Authentication, Firestore, Storage, App Check, Analytics, Crashlytics, Cloud Functions, Messaging
- Images: `image_picker`, `flutter_image_compress`, `cached_network_image`, `flutter_cache_manager`, ML Kit face detection
- Communication/sharing: `url_launcher`, `share_plus`
- Purchases: `in_app_purchase`
- Notifications: `firebase_messaging`, `flutter_local_notifications`
- Moderation/network: `http`, `profanity_filter`
- Utilities: `path`, `path_provider`, `intl`, `audioplayers`
- Localization: Flutter localization delegates, English and Hindi
- Lints: `flutter_lints`

Use package versions compatible with Dart 3.12 and the current stable Flutter SDK. The reference dependency baseline is:

```yaml
provider: ^6.1.5+1
firebase_core: ^4.12.1
firebase_auth: ^6.5.6
cloud_firestore: ^6.7.1
firebase_storage: ^13.4.5
firebase_app_check: ^0.4.5+2
firebase_crashlytics: ^5.2.6
firebase_analytics: ^12.4.5
cloud_functions: ^6.3.5
firebase_messaging: ^16.0.4
image_picker: ^1.2.3
cached_network_image: ^3.4.1
flutter_cache_manager: ^3.4.1
flutter_image_compress: ^2.4.0
google_mlkit_face_detection: ^0.14.0
flutter_local_notifications: ^19.4.0
in_app_purchase: ^3.2.3
audioplayers: ^6.8.1
```

Configure Firebase through generated-style `firebase_options.dart`, but use placeholders or a newly supplied project configuration rather than embedding credentials. The historical deployment project name may be documented as `marriage-71efc`; do not assume access to it.

## Product and visual direction

Build a warm, calm, mobile-first interface rather than a generic admin UI.

- Material 3 light theme.
- Colors:
  - rose `#9B3B5A`
  - deep rose `#7A2E48`
  - amber `#D4A373`
  - cream `#FFF8F3`
  - dark cream `#F5E6DC`
  - ink `#2C1E22`
  - muted `#6B555C`
  - surface `#FFFBFA`
  - WhatsApp `#25D366`
  - Telegram/jobs blue `#229ED9`
  - male tint `#4A6FA5`
  - bikes green `#5B7C5A`
  - home-help teal `#2A9D8F`
- Use Georgia-like serif styling for major headings and normal sans-serif body text.
- Rounded 14–20 px controls/cards, white surfaces, low/no elevation, generous touch targets, restrained shadows.
- Support narrow phones and responsive web without over-wide cards.
- Accessibility: semantic labels/tooltips, readable contrast, text scaling, keyboard-safe forms, and no gesture-only critical action without a discoverable hint.

## Top-level navigation and domain tuner

Create a `HomeShell` with four bottom destinations:

1. Domain-specific Browse/Discover
2. Likes
3. Me
4. Guide

The first destination is a **radio tuner knob**:

- Tap selects Browse.
- Long-press opens a radio-dial overlay for switching domains.
- Play a bundled rotary-click sound when tuning.
- Show a one-time coach mark for up to eight seconds, persisted with `SharedPreferences`.
- Do not run the looping hint animation during widget tests.
- Preserve a separate selected tab index for every domain.

Stations:

- Marriage — 91.2, rose, enabled
- Jobs — 94.5, blue, enabled
- Rooms — 98.1, amber, disabled
- Bikes — 101.7, green, disabled
- Home Help — 107.7, teal, disabled

Disabled stations show a polished “coming soon” view. Keep their forms/stores/repositories implemented behind the release boundary.

## App startup and routing

At startup:

1. Initialize Flutter binding and transparent status bar.
2. On web use path URL strategy.
3. Best-effort initialize Firebase and App Check; failure must not prevent first frame.
4. Configure Firestore persistence with a 15 MiB cache.
5. Configure a low-footprint image cache (approximately 40 decoded images / 12 MiB plus disk cache).
6. Initialize all stores and local preferences before `runApp`.
7. Backfill shared identity from an existing Marriage profile if needed.
8. Load discovery feeds, then apply locally blocked user IDs.
9. Start FCM initialization without blocking the UI.
10. Register all stores/services through `MultiProvider`.

Routes:

- `/` → `HomeShell`
- `/c/:slug` → public share-card screen
- Firebase Hosting must rewrite unknown routes to `/index.html`.

Initialize Analytics best-effort. On mobile, route Flutter/platform errors to Crashlytics and disable Crashlytics collection in debug mode.

## Architecture and directory layout

Use this conceptual structure:

```text
lib/
  config/
  firebase/
  l10n/
  models/
  screens/
  services/
    image_pipeline/
    moderation/
  state/
  theme/
  utils/
  widgets/
    onboarding/
test/
initial_seeds/
firebase/
  functions/
  scripts/
```

Core state:

- `IdentityStore`
- `ProfileStore`
- `JobsProfileStore`
- `RoomsOfferStore`
- `BikesOfferStore`
- `HomeHelpOfferStore`
- one `DiscoveryStore` specialization per domain
- `DomainController`
- `MatchPreferencesStore`
- `JobsDiscoverPrefsStore`
- `BlockStore`
- `LocaleController`
- `TrustService`
- `BillingService`

Stores must:

- paint local/cache/seed data quickly;
- synchronize remotely through repositories when Firebase is ready;
- expose loading/sync/error state without making screens Firebase-aware;
- survive remote failure;
- notify listeners only when useful;
- keep domain data isolated.

Implement scoped sync engines for Marriage, Jobs, Rooms, Bikes, and Home Help so a user’s local state and owned remote document(s) converge predictably.

## Canonical domain policies

Implement `AppDomainId`, `AppDomain`, `DomainPolicy`, `MediaPolicy`, `OfferSubject`, and `DomainStorageKind`.

Policies:

- Marriage:
  - `profiles` storage
  - person subject
  - face media required
  - one profile
  - up to 3 photos
- Jobs:
  - `profiles` storage
  - person subject
  - face media required
  - one profile
  - up to 3 photos
  - roles `seek`, `offer`
- Rooms:
  - `offers` storage
  - asset subject/media
  - up to 5 offers per user
  - up to 8 photos
  - role `have`
- Bikes:
  - `offers` storage
  - asset subject/media
  - up to 5 offers per user
  - exactly 4 photos required on create (max 4)
  - role `lend`
- Home Help:
  - `offers` storage
  - person subject but SafeSearch-only asset/either moderation; face is not mandatory
  - up to 3 offers per user
  - up to 4 photos
  - roles `need`, `have`

Keep this registry synchronized with Firestore rules, Storage rules, repository paths, forms, seed loaders, and tests.

## Shared identity and authentication

Use anonymous Firebase Authentication for low-friction browsing and profile creation. Upgrade/verify through phone OTP only when a user attempts a privacy-sensitive connection.

Shared identity fields:

- `userId`
- display name (trimmed, minimum 2 characters)
- WhatsApp number (digits only, minimum 8 digits)
- city ID and label
- native language, not empty or “Prefer not to say”
- up to three identity photos, with denormalized thumb/medium/large URLs
- trust flags

Identity is stored once under `users/{uid}` and reused across domains. Private contact data is stored at `users/{uid}/private/contact`. FCM token is stored at `users/{uid}/private/push`.

Build:

- identity onboarding form;
- progressive phone OTP bottom sheet;
- OTP send cooldown/throttle via `otp_trackers/{uid}` and phone-hash docs;
- identity backfill from legacy Marriage profile;
- account deletion that removes owned application data where allowed;
- locale selector;
- settings and community standards.

Do not require phone OTP merely to browse, create, swipe, or like.

## Marriage experience

Marriage profile:

- required: identity, age 18+, gender, seeking, short trimmed bio, location/city, at least one acceptable face photo;
- optional tap-to-pick fields: salary band, religion, native language, marital status, height, education, occupation, diet, community;
- derive an equality-friendly `ageBand`: `18-24`, `25-29`, `30-34`, `35-39`, `40-49`, `50+`;
- use chips/dropdowns and skip-friendly onboarding to minimize typing.

Discovery:

- vertically scrolling category/city sections;
- each section contains a swipe-card stack;
- right swipe likes, left swipe rejects;
- image gallery paging inside cards;
- filter sheet for gender/seeking, city, age band, and supported preferences;
- page size 20;
- exclude the current user, blocked users, and already actioned cards;
- support refresh/reset and app-invite empty states.

When a right swipe produces mutual interest, show a match-moment dialog. Contact still requires the privacy checks described below.

## Jobs experience

Support two roles:

- `seek`: person seeking work;
- `offer`: person/employer offering work.

Use tap-to-pick trades:

- Cook
- Driver
- Domestic help
- Delivery
- Security
- Construction
- Electrician
- Plumber
- Warehouse
- Shop/Retail
- Office/Desk
- Cleaning

Use monthly salary bands:

- Prefer not to say
- Under ₹10k/mo
- ₹10–15k/mo
- ₹15–25k/mo
- ₹25–40k/mo
- ₹40–60k/mo
- ₹60k+/mo

Generate short need lines instead of forcing biography typing, e.g. “Looking for driver work” or “Need driver help.” Include job title, trade ID, categories, salary band, city, role, identity photo, and trust flags. Add Jobs-specific discovery preferences for role/trade/city and Jobs-specific card labels.

## Rooms foundation

Implement landlord listing creation and editing:

- listing type: Room, Studio, 1 BHK, 2 BHK, 3 BHK, PG;
- furnishing: Unfurnished, Semi, Fully furnished;
- monthly rent presets ₹8k, ₹12k, ₹15k, ₹20k, ₹25k, ₹35k, ₹50k;
- deposit: none or 1/2/3 months;
- amenities: Wi-Fi, AC, Parking, Kitchen, Balcony, Power backup;
- city;
- minimum 2 and maximum 8 asset photos;
- generated title/subtitle;
- optional address trust proof.

## Bikes foundation

Implement lender listing creation and editing:

- Scooter/Bike;
- automatic/geared;
- makes: Honda, Hero, TVS, Bajaj, Yamaha, Royal Enfield, Suzuki, Other;
- optional model;
- hourly rent presets ₹50/80/100/150/200 plus custom value;
- available weekdays;
- from/to time, default 09:00–20:00;
- exactly four asset photos on create;
- generated title/subtitle;
- optional RC and insurance images.

Vehicle documents must be uploaded only to owner-readable Storage paths. Public offers may contain `hasRc` and `hasInsurance` booleans, never `rcUrl`, `insuranceUrl`, or equivalent download URLs.

## Home Help foundation

Implement two-sided listing creation:

- `have`: worker available;
- `need`: household hiring;
- roles: Cook, Maid, Ayah/Nanny, Elder care, Driver, Deep cleaner;
- shifts: Part-time, Full-time, Live-in;
- salary bands: ₹5–8k, ₹8–12k, ₹12–18k, ₹18–25k, ₹25k+;
- selectable languages: Hindi, English, Marathi, Tamil, Telugu, Kannada, Bengali, Gujarati, Punjabi, Malayalam;
- worker listings need at least one photo; household requests may be photo-optional;
- up to four photos;
- generated title/subtitle, no unnecessary free text.

## Discovery inventory and seed bundle

Create a deterministic bundled seed system that paints immediately in debug/profile and release web, and acts as empty-feed fallback on release mobile.

Seed all five domains across:

- Mumbai & MMR
- Delhi NCR
- Bengaluru

Use three category/city groups and three cards per category for each domain (nine cards/domain), with three distinct synthetic WebP images per card:

- 5 domains
- 45 cards
- 135 images
- portrait dimensions approximately 1800×2400
- every image must have a unique SHA-256 hash

Create:

```text
initial_seeds/manifest.json
initial_seeds/profiles.json
initial_seeds/categories.json
initial_seeds/photos/
initial_seeds/jobs/profiles.json
initial_seeds/jobs/categories.json
initial_seeds/jobs/photos/
initial_seeds/rooms/offers.json
initial_seeds/rooms/categories.json
initial_seeds/rooms/photos/
initial_seeds/bikes/offers.json
initial_seeds/bikes/categories.json
initial_seeds/bikes/photos/
initial_seeds/home_help/offers.json
initial_seeds/home_help/categories.json
initial_seeds/home_help/photos/
```

Seed contacts are permitted only in debug/demo behavior. Release builds must not expose demo contacts.

Feature behavior:

- `ALLOW_DEMO_SEEDS` compile-time override may force bundled inventory.
- Debug/profile: allow seeds.
- Release web: allow initial seeds.
- Release mobile: prefer healthy remote inventory, but allow seeds only as an empty-feed fallback.
- Demo WhatsApp/Telegram fallback: never in release mode.

## Photo pipeline and moderation

Implement a shared image pipeline:

1. Pick images with platform-appropriate APIs.
2. Enforce slot/domain count limits and maximum 5 MiB uploads.
3. Normalize orientation.
4. Compress to WebP.
5. Produce thumb, medium, and large variants.
6. For Marriage/Jobs, use on-device ML Kit face detection and require at least one single-face portrait.
7. Run text safety/profanity checks before writes.
8. Integrate Google Vision SafeSearch through a client abstraction.
9. Disable billable Vision calls in debug/profile by default; allow a compile-time `ENABLE_VISION_DEV` override.
10. Release builds run SafeSearch as designed.
11. Never log image bytes, Vision response bodies, contact data, or document URLs.
12. Gate any diagnostic logging behind assertions/debug mode.

Support image flagging from discovery cards. Clients may create an `image_flags` record but may never read flags. Provide reasons including underage/child safety and route urgent cases for operations notification.

## Likes, contact privacy, blocking, reporting, and sharing

Likes are domain-scoped:

```text
domains/{domainId}/likes/{viewerUid}/outbound/{targetUid}
domains/{domainId}/likes/{ownerUid}/inbound/{fromUid}
```

Requirements:

- write both directions consistently;
- snapshots may include safe card display fields but never WhatsApp or Telegram;
- support inbound/outbound Likes UI;
- show blurred business/contact card until unlock;
- contact unlock requires a non-anonymous, phone-verified session **and mutual likes**;
- read unlocked contact only from the target’s private contact vault;
- if remote contact is absent, do not invent one in production;
- launch WhatsApp/Telegram through validated URLs;
- allow blocking and immediately remove blocked IDs from every feed;
- allow reporting users/listings and photo-specific flagging;
- support public, non-sensitive share cards at `/c/{slug}`;
- public cards must not contain name, display name, bio, phone, WhatsApp, or Telegram; use safe redacted presentation data.

Add a community standards dialog and safety-actions sheet.

## Trust, freshness, boost, and monetization

Implement trust flags and badges:

- verified user / Aadhaar;
- trusted ID / driving licence;
- ID+ when both exist;
- trusted address for applicable room listing;
- trusted RC for applicable bike listing;
- refreshed today;
- active promoted ad/boost.

Trust document workflow:

1. User selects a document image.
2. Upload to `verify_staging/{uid}/{docType}/...`.
3. Set only the appropriate trust boolean/timestamp.
4. Fan out safe trust flags to owned cards.
5. Delete the staged object immediately in a `finally` block.

Do not claim cryptographic or government verification. Label self-attested flows honestly.

Provide one free listing refresh per calendar day. Refresh stamps owned cards with `refreshedAt`.

Implement Android Play Billing product `flut_boost_week`:

- non-consumable-style seven-day entitlement behavior;
- persist `boostUntil` locally and in the user trust record;
- fan out boost timestamp to owned cards;
- active boost places cards on an Ads shelf;
- web displays that purchases are Android-only;
- a debug grant helper may exist but must never appear in release UX;
- boost must never bypass mutual-like contact privacy.

## Firestore data model

Use these canonical locations:

```text
profiles/{uid}                                  # legacy-compatible Marriage
users/{uid}                                     # shared identity and safe trust
users/{uid}/private/contact                     # private contact vault
users/{uid}/private/push                        # FCM token
domains/marriage/profiles/{uid}
domains/jobs/profiles/{uid}
domains/{rooms|bikes|home_help}/offers/{offerId}
domains/{domainId}/discovery_categories/{id}
domains/{domainId}/public_cards/{slug}
domains/{domainId}/likes/{uid}/outbound/{id}
domains/{domainId}/likes/{uid}/inbound/{id}
users/{uid}/blocks/{targetUid}
reports/{id}
image_flags/{id}
rate_limits/{uid}
otp_trackers/{uid}                               # and phone-hash docs `p_{hash}`
waitlists/{domain_uid}                          # coming-soon domain waitlist
```

Person profiles contain safe discovery information, photo variants, city/category fields, role/domain fields, trust/freshness flags, and timestamps. Their public discovery copies must keep contact fields empty.

Marriage dual-writes legacy `profiles/{uid}` and canonical `domains/marriage/profiles/{uid}` for compatibility. Jobs writes only the domain path. Offers live only under domain offer collections.

Present-state caveats to reproduce accurately unless explicitly hardening beyond current behavior:
- trust/boost/refresh timestamps are written by the client; there is no server receipt validation for Play purchases;
- Firebase CLI deploys run from the `firebase/` directory (root `firebase.json` is FlutterFire metadata only);
- legal pages live under `web/legal/` and ship with the web build into Hosting;
- contact-vault rules may currently accept mutual likes across domains; the client checks the selected domain — prefer same-domain mutual likes in both rules and client when rebuilding;
- account deletion is client-driven and incomplete for some subcollections/public cards — match present behavior or document a server-side deletion improvement as out of scope.

Offers contain:

- ID, domain/domainId, ownerId/userId;
- generated title, optional role, short body;
- city ID/label;
- category tags;
- photo variants and canonical media path;
- domain-specific `attributes`;
- active state;
- optional expiry, refresh, and boost timestamps;
- created/updated timestamps.

Public offer attributes must explicitly reject:

- `whatsappNumber`
- `telegramHandle`
- `phone`
- `rcUrl`
- `insuranceUrl`

## Firebase Storage paths

Use:

```text
profile_photos/{uid}/...
profile_photos/{uid}/identity/{slot}/...
profile_photos/{uid}/{domainId}/{slot}/...
media/{uid}/{domainId}/{offerId}/{slot}/...
media/{uid}/{domainId}/{offerId}/docs/{rc|insurance}/...
verify_staging/{uid}/{docType}/...
```

Rules:

- uploads must be under 5 MiB;
- allowed image MIME types: WebP, JPEG/JPG, PNG;
- profile and public listing photos: owner writes, public reads;
- RC/insurance paths: owner writes and owner-only reads;
- verification staging: owner-only;
- no broad list/write rules.

## Firestore security rules

Write strict, tested rules with helper functions for authentication, ownership, field validation, contact redaction, and allowed domain IDs.

Enforce:

- owner-only writes for `profiles/{uid}`, `users/{uid}`, domain profiles, and offers;
- public discovery profiles have empty WhatsApp/Telegram fields;
- only owner can read/write the contact vault, except an eligible non-anonymous mutual-like viewer may read the target contact record;
- no top-level contact data on offers;
- banned contact/document URL keys inside `attributes`;
- public cards contain no name, displayName, bio, phone, WhatsApp, or Telegram;
- like snapshots contain no contact fields;
- image flags are authenticated create-only and unreadable by clients;
- reports are create-only for eligible reporters;
- rate-limit documents are owner-scoped and hits are capped at 10;
- immutable owner/domain identity where appropriate;
- sensible string lengths, list sizes, type checks, and photo limits;
- updates cannot smuggle forbidden fields that create validation would reject.

Treat rule files as canonical security sources. Add proof tests that inspect or emulator-test every critical invariant.

## Firestore indexes

Create composite indexes for:

- offers: `cityId + active`;
- offers: `ownerId + active`;
- offers: `cityId + categoryTags(array contains) + active`;
- profiles: `gender + updatedAt desc`;
- profiles: `cityId + updatedAt desc`;
- profiles: `cityId + gender + updatedAt desc`;
- profiles: `ageBand + updatedAt desc`;
- profiles: `cityId + ageBand + updatedAt desc`;
- profiles: `cityId + gender + ageBand + updatedAt desc`;
- profiles: `jobsRole + updatedAt desc`;
- profiles: `tradeId + updatedAt desc`;
- profiles: `cityId + jobsRole + updatedAt desc`;
- profiles: `cityId + tradeId + updatedAt desc`;
- profiles: `cityId + jobsRole + tradeId + updatedAt desc`.

Avoid queries with more than one inequality filter.

## Abuse controls and Cloud Functions

Implement Node.js 20 Firebase Functions with `firebase-admin` and `firebase-functions`:

1. `onReportCreated`
   - send an optional Slack webhook summary;
   - treat underage/child-safety reasons as urgent;
   - if `SLACK_WEBHOOK_URL` is unset, log a short warning and succeed.
2. `onImageFlagCreated`
   - same safety notification behavior.
3. Callable `checkFeedThrottle`
   - require authentication;
   - transactionally allow at most 10 hits per 30-second window;
   - set and return `lockedUntilMs`.
4. `onInboundLikeCreated`
   - load the target owner’s private FCM token;
   - send high-priority “Liked you” notification;
   - include only safe display data.

Pair the callable with a client-side feed throttle of 10 requests per 30 seconds. Feed failure or function unavailability should degrade gracefully rather than crash.

## Push notifications

- Request/setup messaging best-effort on supported mobile platforms.
- Create high-priority Android channel `flut_likes_high`.
- Persist FCM token privately.
- Handle inbound-like payloads safely.
- Notifications must not expose contact details.
- Web/mobile unsupported states must be harmless.

## Localization

Provide English and Hindi for primary navigation, discovery, filter, boost, match, profile, empty, and safety strings. Use a lightweight locale controller persisted locally. System locale is the default; users may force `en` or `hi`.

## Me, Likes, and Guide screens

`Me` is one account hub across domains:

- shared identity summary/editor;
- badge grid and expandable “Earn next” panel;
- one activity card per domain with status, count, and edit action;
- domain forms open in a near-full-height bottom sheet;
- Refresh/Boost/Ads controls;
- account settings, language, standards, and deletion.

`Likes`:

- domain-aware inbound/outbound liked cards;
- safe blurred contact presentation;
- block/report actions;
- connection flow through OTP and mutual-like checks.

`Guide`:

- explain swiping, the domain tuner, mutual interest, privacy, safety/reporting, trust labels, seed/demo limitations, and contact behavior;
- do not make unverifiable safety or identity claims.

## Public web and hosting

- Build web release successfully.
- Use path URLs and support direct loads of `/c/:slug`.
- Configure Firebase Hosting SPA rewrite.
- Use immutable one-year cache headers for versioned assets, icons, fonts, and images.
- Use no-cache/no-store for the app shell so deployments update reliably.
- Keep generated hosting output under `firebase/public` only as a deploy artifact.

## Testing requirements

Create focused unit/widget/proof tests equivalent in coverage to these suites:

- widget smoke/navigation;
- onboarding flow controller;
- onboarding sheet flow;
- domain radio dial;
- profile and domain policy contracts;
- feature flag foundation;
- core verification matrix;
- user workflow matrix;
- end-to-end workflow proof;
- Marriage/Jobs preferences;
- OTP send throttle;
- contact unlock;
- public share-card redaction;
- text safety scanner;
- image compression pipeline;
- image flagging;
- trust flags;
- auth/App Check setup;
- security hardening proof;
- adversarial security-bot proof;
- sprint safety regressions;
- seed manifest/333-style asset contract;
- stress/break behavior.

At minimum, tests must prove:

- all five domain policies have the correct storage/media/cardinality rules;
- enabled/disabled release stations are correct;
- public documents and like snapshots cannot contain contact;
- offers cannot hide contact or document URLs in attributes;
- RC/insurance objects are owner-readable only;
- mutual like plus phone verification gates contact;
- anonymous users cannot unlock contact;
- release demo contacts are disabled;
- profile phone validation requires at least eight digits;
- trimmed bio length is validated;
- image flags are create-only/no-read;
- rate-limit cap is 10;
- seed manifest counts, dimensions, SHA-256 hashes, and uniqueness are consistent with on-disk WebPs (`npm run validate:333`);
- Flutter seed-contract tests alone are not enough if the sharp/hash validator fails;
- billable Vision is off in dev unless explicitly enabled;
- Vision and web App Check keys come from dart-defines / restricted secrets, not hard-coded extractable defaults in release;
- tests never hang on perpetual animations.

Target:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
cd firebase/scripts && npm install && npm run validate:333
node --check ../functions/index.js
```

All must pass with zero analyzer issues. Aim for at least the current reference depth of about **238** passing Flutter tests across the workflow, stress, security, moderation, prefs, onboarding, dial, share-card, contact-unlock, and seed-contract suites—not a thin smoke set.

Security proof tests may inspect rules source for invariants, but also prefer Firebase Rules Unit Testing / emulator denials where practical. Do not treat string-only rules assertions as full live-rule proof.

Also validate:

```bash
flutter build web --release \
  --dart-define=RECAPTCHA_V3_SITE_KEY=YOUR_KEY \
  --dart-define=VISION_API_KEY=YOUR_KEY
flutter build appbundle --release
cd firebase/functions && npm install
```

Use Android application ID `com.matchmaker.flut_marriage`. Release signing must not silently fall back to the debug keystore for Play uploads.

If Linux desktop is tested, document that `audioplayers_linux` may require the system GStreamer development package; this is not an application defect.

## Operational files and deployment

Create:

- root and `firebase/` Firebase configurations;
- `.firebaserc` or documented project selection;
- `firebase/firestore.rules`;
- `firebase/storage.rules`;
- `firebase/firestore.indexes.json`;
- `firebase/functions/package.json` using Node 20;
- `firebase/functions/index.js`;
- scripts for safe seed deployment and legacy data cleanup;
- `.gitignore` entries for Admin SDK keys, service accounts, `.env`, build outputs, and local Firebase logs;
- a production readiness report;
- a concise README with setup, run, test, and deploy instructions.

Deployment commands should be documented, not executed against production without explicit authorization:

```bash
cd firebase
npm --prefix functions ci
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
cd ..
flutter build web --release \
  --dart-define=RECAPTCHA_V3_SITE_KEY=... \
  --dart-define=VISION_API_KEY=...
rsync -a --delete build/web/ firebase/public/
cd firebase && firebase deploy --only hosting
cd .. && flutter build appbundle --release
```

For optional Play hardening:

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info
```

Keep debug-info artifacts private and retained for crash deobfuscation.

## Legacy cleanup and migration safety

Admin seed/reseed scripts must not write WhatsApp/Telegram into signed-in-readable discovery profiles. Put demo contacts only in the private contact vault, and keep public contact fields empty even when using the Admin SDK.

Provide an Admin SDK script, requiring `GOOGLE_APPLICATION_CREDENTIALS` outside the repository, that scans bike offers and:

- converts any legacy `attributes.rcUrl` into `attributes.hasRc = true`;
- converts any legacy `attributes.insuranceUrl` into `attributes.hasInsurance = true`;
- deletes both URL fields;
- leaves private Storage objects untouched;
- logs only offer IDs, never URLs.

Document that leaked/shared Admin SDK keys must be rotated.

## Required completion sequence

Work in this order:

1. Scaffold project, dependencies, theme, models, and domain policies.
2. Implement local-first stores and deterministic seeds.
3. Implement shell, radio tuner, Browse, Likes, Me, Guide, and public route.
4. Implement shared identity/auth and Marriage.
5. Implement Jobs.
6. Implement Rooms, Bikes, and Home Help foundations while keeping them disabled publicly.
7. Implement image pipeline and moderation.
8. Implement Firebase repositories, sync, likes, contact vault, blocking, reporting, and sharing.
9. Implement trust, refresh, boost, billing, and notifications.
10. Write Firestore/Storage rules, indexes, functions, and scripts.
11. Add all tests and adversarial proof cases.
12. Run formatter, analyzer, tests, web build, and Android bundle build.
13. Fix every failure within scope.
14. Produce README and final production-readiness report.

## Definition of done

Do not claim completion until:

- the app starts without Firebase and shows synthetic inventory;
- it starts with Firebase and syncs remote data;
- Marriage and Jobs are usable end-to-end;
- all five domain foundations are present;
- only Marriage and Jobs are enabled in the release tuner;
- public discovery never reveals contact or private documents;
- contact unlock is phone-verified and mutual;
- security rules and proof tests agree;
- no secret or real personal data is in the repository;
- `flutter analyze` reports no issues;
- all tests pass;
- release web and Android App Bundle builds succeed, or any external toolchain blocker is precisely documented with evidence;
- deployment steps are documented without making unauthorized production changes.

At the end, report:

1. what was implemented;
2. the final repository structure;
3. commands and exact outcomes;
4. security invariants proven;
5. build artifact paths;
6. environment-only setup still required;
7. any remaining operational actions that require a human or production authorization.

Do not return only a design document. Build and verify the application.

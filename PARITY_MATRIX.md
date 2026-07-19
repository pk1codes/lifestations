# Prompt-to-code parity matrix

Status: `C` complete · `P` partial · `M` missing · `E` external-only · `O` override (all five domains enabled)

Updated after prompt-parity closure pass.

| Prompt area | Status | Evidence / notes |
|-------------|--------|------------------|
| Project scaffold, deps, theme | C | `pubspec.yaml`, `lib/theme/` |
| Domain policies (all five) | C+O | `lib/models/app_domain.dart` — all enabled |
| Seed inventory 45/135 | C | `initial_seeds/`, `firebase/scripts` validate:333 |
| Shell / tuner / tabs | C | `HomeShell`, coach, rotary |
| Deep share `/c/:slug` | C | Allowlisted `PublicShareCard`, repo, Share UI, path strategy, route screen, rules, tests. Owner publishes; non-owner reuses/ephemeral redacted share |
| Identity + OTP | P→C | Identity sync, OTP sheet, persisted OTP throttle, phone gate on Connect |
| Domain forms (5) | C | Typed forms + `ListingPublisher` sync + `FormMediaController` pick/upload |
| Discovery sync | C | Seeds + remote merge + filters + 20-item paginated `discoverPage` |
| Likes dual-write | C | Atomic outbound/inbound + hydrate on session |
| Contact unlock | C | Callable same-domain + phone; WhatsApp + Telegram launch |
| Block / report / flag | C | Prefs + Firestore blocks; report/flag writers; feed filter |
| Image pipeline + face/SafeSearch | C | Wired via forms; ML Kit FaceDetectionService on mobile; Vision needs dart-define |
| Trust / refresh / boost | C | Self-attest UI, daily refresh, IAP + fan-out (Android); debug grant on desktop |
| FCM / notifications | C | Initializes with Auth uid after bootstrap; graceful skip on web/desktop |
| Firestore/Storage rules | C | Public-card allowlist; vault owner-only; legacy path read-only |
| Functions | C | `unlockContact` + existing moderation/cleanup exports |
| Rules emulator denial suite | P | Source-string contracts + Dart proofs; full `@firebase/rules-unit-testing` still optional |
| Tests | C | 44 Flutter tests covering share/redaction/forms/rules/media/throttle |
| Firebase project / signing / deploy | E | Requires human project + keystore |

## Release boundary override

All five stations (Marriage, Jobs, Rooms, Bikes, Home Help) are **enabled**.
Original prompt “coming soon” for Rooms/Bikes/Home Help is overridden by product request.

## Still external

Credentials, production Firebase config, Play product, App Check/Vision keys, signing secrets, and authorized deploy remain human actions.

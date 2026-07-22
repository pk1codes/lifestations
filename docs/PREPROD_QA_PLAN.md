# Pre-production automated QA plan

Professional release gates for Life Stations (`aaaa-4eee0`), executed in order.

| Gate | Command / check | Pass criteria |
|------|-----------------|---------------|
| G1 Format | `dart format --set-exit-if-changed .` | No drift |
| G2 Analyze | `flutter analyze` | No errors/warnings treated as fail (info OK if documented) |
| G3 Unit/widget | `flutter test --concurrency=1` | All tests pass |
| G4 Backend proofs | `cd firebase/scripts && npm run prove:backend` | Exit 0 |
| G5 Seed assets | `npm run validate:333` (if applicable) | Exit 0 or N/A |
| G6 Functions syntax | `node --check functions/index.js` | Exit 0 |
| G7 Rules contract | firebase/tests public cards rules if present | Exit 0 |
| G8 Web release | `flutter build web --release` (+ SHARE_ORIGIN) | Build succeeds |
| G9 Android AAB | `flutter build appbundle --release` (if signing available) | Build succeeds or documented skip |

**Loop:** For each failing gate → capture error proof → fix → re-run that gate and dependents → continue until all green.

**Report:** Every error logged with gate id, evidence, fix, retest result.

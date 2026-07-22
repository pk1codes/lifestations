# Proof — countdown + Account/Me SMS verify (3.0.39+43)

## Fixes
1. **OTP countdown** — every "Try again in Xs" path uses a 1s tick counter (local throttle + remote claim fail). No frozen "60s".
2. **Account verify** — filled button **Verify phone (SMS)** on Account sheet.
3. **Me verify** — obvious row **Verify phone (SMS)** when WhatsApp saved but not verified.
4. Dial chips/dropdown left as-is (per request).

## Automated proof
```
flutter test --concurrency=1 → All tests passed (see full_fix_prove.log)
Focused: otp_cooldown_ticker_test, me_verify_phone_row_test, account_phone_verify_test, likes_flat_path_test
```

## Ship
- Hosting publish
- AAB versionCode **43**
Tests: 180 passed

# Account Firebase Phone OTP — proof

## Product rule

OTP only on **Account / Me**. WhatsApp / Telegram taps while unverified → “Verify your phone in Account first” → Account form (no OTP sheet from chat).

## Automated

```bash
flutter test \
  test/otp_sms_copy_test.dart \
  test/otp_cooldown_ticker_test.dart \
  test/account_otp_gate_test.dart \
  test/account_phone_verify_test.dart \
  test/me_verify_phone_row_test.dart \
  test/otp_firebase_phone_contract_test.dart
```

Coverage:

- OTP sheet: WhatsApp number locked, **Send code** / **Confirm**, no same-as toggle
- `phoneVerified` only when Firebase Auth `phoneNumber` is set
- `credential-already-in-use` → plain message
- `otp_trackers` write is best-effort (does not block SMS)
- Chat unverified → Account redirect copy

## Device / Play internal checklist

1. Account: save WhatsApp `+91` + `9869610903` (Firebase test number).
2. **Verify phone (SMS)** → **Send code** → enter `111111` → **Confirm**.
3. Me shows verified; Account shows **Phone verified**.
4. Mutual like → WhatsApp opens with **no OTP sheet**.
5. Fresh unverified account → tap WhatsApp on mutual → snackbar → Account opens.

## Ship

Hosting + AAB when you ask (bump version then). Ops: Play SHA in Firebase, Phone Auth on, test numbers for closed testing.

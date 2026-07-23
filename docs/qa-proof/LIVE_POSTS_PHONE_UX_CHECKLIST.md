# Live posts + +91/+965 phone UX — manual checklist

Use two phones (or one phone + emulator) on the same Firebase project / closed-testing build.

## A) Live Browse broadcast (all domains)

1. Phone A: open **Jobs** → post an “I need” Driver (or any demand) listing with a photo.
2. Phone B: stay on **Jobs Browse** with the app open (do not force-quit).
3. **Pass:** Phone B’s feed shows the new post within a few seconds (Firestore snapshot).
4. Phone B: force-quit → reopen → **Pass:** post is present on cold start.
5. Phone B: background the app → Phone A posts another listing → Phone B resumes → pull **Refresh** if needed → **Pass:** new post appears.
6. Repeat once for **Marriage** (profile save) to confirm domain-agnostic listen/refresh.

## B) Phone / WhatsApp inputs (+91 / +965)

1. Account → WhatsApp: chips **+91 | +965**, national digits only (no `+` typing).
2. Enter India test national `9869610903` with **+91** → save.
3. WhatsApp gate (when prompted): same chips + field.
4. **Pass:** stored value is E.164 digits `919869610903` (no doubled `91`).

## C) OTP = Firebase SMS only (not WhatsApp/Telegram)

1. Open **Verify phone** (Account or Me).
2. **Pass:** title **Verify phone**; body says SMS is not WhatsApp/Telegram; button **Send SMS code**.
3. “Same as WhatsApp” is **off** by default on unlock OTP; optional check fills WhatsApp digits.
4. With Firebase **test number** `+919869610903` / code `111111`:
   - Chip **+91** + `9869610903` → Send SMS code → enter `111111` → Verify code.
5. **Pass:** `phoneVerified` / “Phone verified”; WhatsApp/Telegram gates work after mutual like without treating OTP as a chat channel.
6. Telegram remains a **handle** (no dial chips on Telegram).

## D) Regression notes

- Pull-to-refresh and empty-state **Try again** must call a real remote reload (all domains).
- Dial preference (+91/+965) should stick between Account and OTP.

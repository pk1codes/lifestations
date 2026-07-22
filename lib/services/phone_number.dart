/// India / Kuwait dial helpers for Account, WhatsApp gate, and SMS OTP.
library;

enum PhoneDialCode {
  india('91', '+91', 'India'),
  kuwait('965', '+965', 'Kuwait');

  const PhoneDialCode(this.digits, this.label, this.country);
  final String digits;
  final String label;
  final String country;

  static const all = <PhoneDialCode>[india, kuwait];

  static PhoneDialCode fromDigits(String dialDigits) {
    for (final code in all) {
      if (code.digits == dialDigits) return code;
    }
    return PhoneDialCode.india;
  }
}

class PhoneParts {
  const PhoneParts({required this.dial, required this.national});
  final PhoneDialCode dial;
  final String national;
}

/// Preferred national lengths after dial code (loose, necessity-friendly).
int nationalLengthHint(PhoneDialCode dial) => switch (dial) {
  PhoneDialCode.india => 10,
  PhoneDialCode.kuwait => 8,
};

/// Strip non-digits and a leading trunk `0` from national input.
String cleanNational(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) {
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
  }
  return digits;
}

/// Full E.164 digits without `+` (e.g. `919869610903`).
String toE164Digits(PhoneDialCode dial, String nationalRaw) {
  final national = cleanNational(nationalRaw);
  if (national.isEmpty) return '';
  // Already includes dial code — do not double-prepend.
  if (national.startsWith(dial.digits) &&
      national.length > dial.digits.length + 4) {
    return national;
  }
  for (final code in PhoneDialCode.all) {
    if (national.startsWith(code.digits) &&
        national.length >= code.digits.length + 7) {
      return national;
    }
  }
  return '${dial.digits}$national';
}

/// Firebase Auth / SMS format with leading `+`.
String toFirebasePhone(PhoneDialCode dial, String nationalRaw) {
  final e164 = toE164Digits(dial, nationalRaw);
  if (e164.isEmpty) return '';
  return '+$e164';
}

bool isValidE164Digits(String e164Digits) {
  final digits = e164Digits.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8 && digits.length <= 15;
}

String? phoneFieldError(PhoneDialCode dial, String nationalRaw) {
  final national = cleanNational(nationalRaw);
  if (national.isEmpty) return 'Enter your number';
  final e164 = toE164Digits(dial, national);
  if (!isValidE164Digits(e164)) return 'Check the number';
  final local = e164.startsWith(dial.digits)
      ? e164.substring(dial.digits.length)
      : national;
  final hint = nationalLengthHint(dial);
  if (local.length < hint - 2 || local.length > hint + 2) {
    return 'Use about $hint digits';
  }
  return null;
}

/// Split a stored E.164 digit string into dial chip + national field text.
PhoneParts splitStoredPhone(
  String stored, {
  PhoneDialCode fallback = PhoneDialCode.india,
}) {
  final digits = stored.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return PhoneParts(dial: fallback, national: '');
  }
  for (final code in PhoneDialCode.all) {
    if (digits.startsWith(code.digits) &&
        digits.length > code.digits.length + 4) {
      return PhoneParts(
        dial: code,
        national: digits.substring(code.digits.length),
      );
    }
  }
  return PhoneParts(dial: fallback, national: digits);
}

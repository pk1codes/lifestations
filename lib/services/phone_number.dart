/// Dial helpers for Account, WhatsApp gate, and SMS OTP.
library;

enum PhoneDialCode {
  bangladesh('880', '+880', 'Bangladesh'),
  india('91', '+91', 'India'),
  pakistan('92', '+92', 'Pakistan'),
  china('86', '+86', 'China'),
  indonesia('62', '+62', 'Indonesia'),
  egypt('20', '+20', 'Egypt'),
  uae('971', '+971', 'UAE'),
  saudi('966', '+966', 'Saudi'),
  qatar('974', '+974', 'Qatar'),
  oman('968', '+968', 'Oman'),
  kuwait('965', '+965', 'Kuwait');

  const PhoneDialCode(this.digits, this.label, this.country);
  final String digits;
  final String label;
  final String country;

  /// UI order (India + Kuwait first — most common for this app).
  static const all = <PhoneDialCode>[
    india,
    kuwait,
    saudi,
    uae,
    qatar,
    oman,
    egypt,
    pakistan,
    bangladesh,
    indonesia,
    china,
  ];

  /// Longest dial digits first — avoids +880 matching as +86.
  static List<PhoneDialCode> get matchOrder {
    final codes = List<PhoneDialCode>.from(all);
    codes.sort((a, b) => b.digits.length.compareTo(a.digits.length));
    return codes;
  }

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
  PhoneDialCode.pakistan => 10,
  PhoneDialCode.bangladesh => 10,
  PhoneDialCode.china => 11,
  PhoneDialCode.indonesia => 10,
  PhoneDialCode.egypt => 10,
  PhoneDialCode.kuwait => 8,
  PhoneDialCode.saudi => 9,
  PhoneDialCode.uae => 9,
  PhoneDialCode.qatar => 8,
  PhoneDialCode.oman => 8,
};

/// Dummy guidance digits only — never real test-console numbers.
String nationalHintExample(PhoneDialCode dial) => switch (dial) {
  PhoneDialCode.india => '9876543210',
  PhoneDialCode.pakistan => '3001234567',
  PhoneDialCode.bangladesh => '1712345678',
  PhoneDialCode.china => '13812345678',
  PhoneDialCode.indonesia => '8123456789',
  PhoneDialCode.egypt => '1001234567',
  PhoneDialCode.kuwait => '50123456',
  PhoneDialCode.saudi => '501234567',
  PhoneDialCode.uae => '501234567',
  PhoneDialCode.qatar => '33123456',
  PhoneDialCode.oman => '92123456',
};

/// Dummy 6-digit OTP hint (not a Firebase test code).
const otpCodeHintExample = '123456';

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
  for (final code in PhoneDialCode.matchOrder) {
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
  for (final code in PhoneDialCode.matchOrder) {
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

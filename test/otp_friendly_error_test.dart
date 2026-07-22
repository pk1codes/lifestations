import 'package:firebase_auth/firebase_auth.dart';
import 'package:flut_marriage/widgets/onboarding/otp_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('friendlyOtpError maps common Firebase codes', () {
    expect(
      friendlyOtpError(
        FirebaseAuthException(code: 'invalid-phone-number', message: 'raw'),
      ),
      'Check the phone number and try again.',
    );
    expect(
      friendlyOtpError(
        FirebaseAuthException(code: 'invalid-verification-code', message: 'x'),
      ),
      'That code is wrong or expired. Request a new code.',
    );
    expect(
      friendlyOtpError(
        FirebaseAuthException(code: 'too-many-requests', message: 'x'),
      ),
      'Too many tries. Wait a bit, then retry.',
    );
    expect(
      friendlyOtpError(FirebaseAuthException(code: 'mystery', message: '')),
      'Could not verify phone. Try again.',
    );
  });
}

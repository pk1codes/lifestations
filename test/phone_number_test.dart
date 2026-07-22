import 'package:flut_marriage/services/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toE164Digits / toFirebasePhone', () {
    test('India national builds test number without doubling 91', () {
      expect(toE164Digits(PhoneDialCode.india, '9869610903'), '919869610903');
      expect(
        toFirebasePhone(PhoneDialCode.india, '9869610903'),
        '+919869610903',
      );
    });

    test('already-E.164 India digits are not doubled', () {
      expect(toE164Digits(PhoneDialCode.india, '919869610903'), '919869610903');
      expect(
        toFirebasePhone(PhoneDialCode.india, '919869610903'),
        '+919869610903',
      );
    });

    test('Kuwait national builds correctly', () {
      expect(toE164Digits(PhoneDialCode.kuwait, '65620675'), '96565620675');
      expect(toFirebasePhone(PhoneDialCode.kuwait, '65620675'), '+96565620675');
    });

    test('strips spaces and leading zero', () {
      expect(toE164Digits(PhoneDialCode.india, '09869 610903'), '919869610903');
    });
  });

  group('splitStoredPhone', () {
    test('splits India E.164 for form fields', () {
      final parts = splitStoredPhone('919869610903');
      expect(parts.dial, PhoneDialCode.india);
      expect(parts.national, '9869610903');
    });

    test('splits Kuwait E.164', () {
      final parts = splitStoredPhone('96565620675');
      expect(parts.dial, PhoneDialCode.kuwait);
      expect(parts.national, '65620675');
    });
  });

  test('phoneFieldError rejects empty and accepts test national', () {
    expect(phoneFieldError(PhoneDialCode.india, ''), isNotNull);
    expect(phoneFieldError(PhoneDialCode.india, '9869610903'), isNull);
  });
}

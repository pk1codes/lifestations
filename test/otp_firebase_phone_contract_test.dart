import 'package:flut_marriage/services/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract: dial chip + national digits → Firebase Auth `verifyPhoneNumber`.
void main() {
  test('India test number: +91 chip + 9869610903 → +919869610903 for Auth', () {
    const dial = PhoneDialCode.india;
    const national = '9869610903';

    expect(phoneFieldError(dial, national), isNull);
    expect(toE164Digits(dial, national), '919869610903');
    expect(toFirebasePhone(dial, national), '+919869610903');
  });

  test('pasting full E.164 national does not double dial for Auth', () {
    expect(
      toFirebasePhone(PhoneDialCode.india, '919869610903'),
      '+919869610903',
    );
  });

  test('Kuwait dropdown + local digits builds Auth phone', () {
    expect(toFirebasePhone(PhoneDialCode.kuwait, '65620675'), '+96565620675');
  });

  test('Kuwait Firebase test number: +965 + 90977001 → +96590977001', () {
    expect(toFirebasePhone(PhoneDialCode.kuwait, '90977001'), '+96590977001');
    expect(phoneFieldError(PhoneDialCode.kuwait, '90977001'), isNull);
  });
}

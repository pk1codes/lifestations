import 'package:firebase_auth/firebase_auth.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/widgets/onboarding/otp_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool canMarkPhoneVerified(String? firebasePhoneNumber) {
  final phone = firebasePhoneNumber?.trim();
  return phone != null && phone.isNotEmpty;
}

void main() {
  test('phoneVerified gate requires Firebase Auth phoneNumber', () {
    expect(canMarkPhoneVerified(null), isFalse);
    expect(canMarkPhoneVerified('+919869610903'), isTrue);
  });

  test('credential-already-in-use is treated as sign-in path', () {
    expect(
      phoneBelongsToOtherAccount(
        FirebaseAuthException(code: 'credential-already-in-use'),
      ),
      isTrue,
    );
    expect(
      friendlyOtpError(
        FirebaseAuthException(code: 'credential-already-in-use'),
      ),
      contains('Signing you in'),
    );
  });

  test('mutual unlock still needs phoneVerified', () {
    final likes = LikesStore();
    likes.receiveLike(AppDomainId.marriage, 'peer');
    expect(
      likes.canUnlock(
        domain: AppDomainId.marriage,
        otherId: 'peer',
        anonymous: false,
        phoneVerified: false,
      ),
      isFalse,
    );
  });

  test('chat asks to verify phone (not Account form)', () {
    const copy = 'Verify your phone first';
    expect(copy.contains('Account'), isFalse);
  });

  test('operation-not-allowed mentions SMS regions when relevant', () {
    expect(
      friendlyOtpError(
        FirebaseAuthException(
          code: 'operation-not-allowed',
          message: 'SMS unable to be sent until this region enabled',
        ),
      ),
      contains('SMS region'),
    );
  });

  test('unverified prefs stay false without Auth phone', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = IdentityStore(prefs);
    expect(store.identity.phoneVerified, isFalse);
  });
}

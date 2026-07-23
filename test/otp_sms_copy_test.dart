import 'package:firebase_auth/firebase_auth.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/widgets/onboarding/otp_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Phone OTP is editable number + Send code only', (tester) async {
    SharedPreferences.setMockInitialValues({
      'identity_phone': '919869610903',
      'identity_dial_code': '91',
    });
    final prefs = await SharedPreferences.getInstance();
    final identity = IdentityStore(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: identity)],
        child: const MaterialApp(home: Scaffold(body: OtpSheet())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verify phone'), findsOneWidget);
    expect(find.textContaining('Enter your phone'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.byKey(const Key('otp_send')), findsOneWidget);
    expect(find.byKey(const Key('otp_code_field')), findsNothing);
    expect(find.text('Name'), findsNothing);
    expect(
      find.text('Save your WhatsApp number in Account first.'),
      findsNothing,
    );

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.enabled, isTrue);
  });

  test('friendlyOtpError covers captcha and auth domain failures', () {
    expect(
      friendlyOtpError(FirebaseAuthException(code: 'captcha-check-failed')),
      contains('Security check'),
    );
    expect(
      friendlyOtpError(FirebaseAuthException(code: 'operation-not-allowed')),
      contains('Firebase settings'),
    );
  });

  test('phoneBelongsToOtherAccount detects link conflicts', () {
    expect(
      phoneBelongsToOtherAccount(
        FirebaseAuthException(code: 'credential-already-in-use'),
      ),
      isTrue,
    );
    expect(
      phoneBelongsToOtherAccount(
        FirebaseAuthException(code: 'invalid-verification-code'),
      ),
      isFalse,
    );
  });
}

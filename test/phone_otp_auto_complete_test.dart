import 'package:flut_marriage/services/phone_number.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/widgets/forms/dial_code_phone_field.dart';
import 'package:flut_marriage/widgets/onboarding/otp_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('hints are dummy digits, not Firebase test numbers', () {
    expect(nationalHintExample(PhoneDialCode.india), '9876543210');
    expect(nationalHintExample(PhoneDialCode.kuwait), '50123456');
    expect(otpCodeHintExample, '123456');
    expect(nationalHintExample(PhoneDialCode.india), isNot('9869610903'));
    expect(otpCodeHintExample, isNot('111111'));
  });

  testWidgets('OTP code hint is dummy 123456', (tester) async {
    SharedPreferences.setMockInitialValues({
      'identity_phone': '919876543210',
      'identity_dial_code': '91',
    });
    final prefs = await SharedPreferences.getInstance();
    final identity = IdentityStore(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: identity)],
        child: const MaterialApp(
          home: Scaffold(
            body: OtpSheet(debugStartWithVerificationId: 'vid'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const Key('otp_code_field')));
    expect(field.decoration?.hintText, otpCodeHintExample);
    expect(find.text('111111'), findsNothing);
  });

  testWidgets('phone field calls onComplete at full length', (tester) async {
    var completed = 0;
    var dial = PhoneDialCode.india;
    final phone = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return DialCodePhoneField(
                dial: dial,
                controller: phone,
                onDialChanged: (code) => setState(() => dial = code),
                onComplete: () => completed++,
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '9876543210');
    await tester.pump();
    expect(completed, 1);
  });
}

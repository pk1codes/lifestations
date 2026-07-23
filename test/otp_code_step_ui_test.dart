import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/widgets/onboarding/otp_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('after send, code field and Confirm are shown', (tester) async {
    SharedPreferences.setMockInitialValues({
      'identity_phone': '919869610903',
      'identity_dial_code': '91',
    });
    final prefs = await SharedPreferences.getInstance();
    final identity = IdentityStore(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: identity)],
        child: const MaterialApp(
          home: Scaffold(
            body: OtpSheet(debugStartWithVerificationId: 'test-verification-id'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('otp_code_field')), findsOneWidget);
    expect(find.byKey(const Key('otp_confirm')), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.textContaining('6-digit code'), findsWidgets);
    expect(find.byKey(const Key('otp_sent_to')), findsOneWidget);
    expect(find.text('+919869610903'), findsOneWidget);
  });
}

import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/widgets/onboarding/otp_sheet.dart';
import 'package:flut_marriage/widgets/onboarding/whatsapp_gate_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('contact share dialog offers same vs different', (tester) async {
    SharedPreferences.setMockInitialValues({
      'identity_phone': '919876543210',
      'identity_phone_verified': true,
      'identity_contact_share_chosen': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final identity = IdentityStore(prefs);
    debugHasLivePhoneAuth = ([_]) => true;
    addTearDown(() => debugHasLivePhoneAuth = null);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: identity)],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () => ensureContactShareForChat(context),
                  child: const Text('Open chat'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open chat'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('contact_share_choice_dialog')),
      findsOneWidget,
    );
    expect(find.text('Use same'), findsOneWidget);
    expect(find.text('Different number'), findsOneWidget);

    await tester.tap(find.byKey(const Key('contact_share_same')));
    await tester.pumpAndSettle();

    expect(identity.identity.contactShareChosen, isTrue);
    expect(hasWhatsAppNumber(identity.identity), isTrue);
  });

  test('Identity keeps contactShareChosen separate from phoneVerified', () {
    const id = Identity(
      phoneVerified: true,
      whatsappNumber: '919876543210',
      contactShareChosen: false,
    );
    expect(id.phoneVerified, isTrue);
    expect(id.contactShareChosen, isFalse);
    expect(id.copyWith(contactShareChosen: true).contactShareChosen, isTrue);
  });
}

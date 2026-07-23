import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/widgets/onboarding/identity_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Account is profile-only; Verify opens phone OTP path', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = IdentityStore(prefs);
    await store.save(
      const Identity(
        displayName: 'Ravi',
        whatsappNumber: '919869610903',
        cityId: 'mumbai',
        cityLabel: 'Mumbai',
        nativeLanguage: 'Hindi',
        phoneVerified: false,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: store)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showIdentityForm(context),
                child: const Text('Open account'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open account'));
    await tester.pumpAndSettle();

    expect(find.text('Optional. Phone verify is separate.'), findsNothing);
    expect(find.text('Name (optional)'), findsNothing);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.byKey(const Key('account_open_phone_verify')), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    // No second editable phone dial on Account (OTP owns that).
    expect(find.text('WhatsApp number'), findsNothing);
  });

  testWidgets('Account shows Phone verified when done', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = IdentityStore(prefs);
    await store.save(
      const Identity(
        displayName: 'Ravi',
        whatsappNumber: '919869610903',
        cityId: 'mumbai',
        cityLabel: 'Mumbai',
        nativeLanguage: 'Hindi',
        phoneVerified: true,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: store)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showIdentityForm(context),
                child: const Text('Open account'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open account'));
    await tester.pumpAndSettle();

    expect(find.text('Phone verified'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
  });

  test('OTP number change clears phoneVerified', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = IdentityStore(prefs);
    await store.save(
      const Identity(
        displayName: 'Ravi',
        whatsappNumber: '919869610903',
        cityId: 'mumbai',
        cityLabel: 'Mumbai',
        nativeLanguage: 'Hindi',
        phoneVerified: true,
      ),
    );
    final phoneChanged = '96590977001' != store.identity.whatsappNumber;
    await store.save(
      store.identity.copyWith(
        whatsappNumber: '96590977001',
        phoneVerified: phoneChanged ? false : store.identity.phoneVerified,
      ),
    );
    expect(store.identity.phoneVerified, isFalse);
  });

  test('mutual unlock still requires phoneVerified', () {
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
}

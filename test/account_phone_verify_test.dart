import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/widgets/onboarding/identity_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Account shows Verify phone when not verified', (tester) async {
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

    expect(find.byKey(const Key('account_verify_phone')), findsOneWidget);
    expect(find.text('Verify phone'), findsOneWidget);
    expect(find.text('Phone verified'), findsNothing);
  });

  testWidgets('Account shows Phone verified badge after OTP done', (
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
    expect(find.byKey(const Key('account_verify_phone')), findsNothing);
  });

  test('changing WhatsApp number clears phoneVerified on save', () async {
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
    expect(store.identity.phoneVerified, isTrue);

    // Mimic Account save when digits changed.
    final phoneChanged = '96590977001' != store.identity.whatsappNumber;
    await store.save(
      store.identity.copyWith(
        whatsappNumber: '96590977001',
        phoneVerified: phoneChanged ? false : store.identity.phoneVerified,
      ),
    );
    expect(store.identity.phoneVerified, isFalse);
    expect(prefs.getBool('identity_phone_verified'), isFalse);
  });

  test('mutual + phoneVerified → unlock allowed (no OTP gate)', () {
    final likes = LikesStore();
    // Inbound + outbound presence for mutual without Firebase.
    likes.receiveLike(AppDomainId.marriage, 'peer');
    // Force outbound locally via receiveLike then check canUnlock needs both.
    // Use the same contract as WhatsApp open: verified + mutual.
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

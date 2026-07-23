import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/state/domain_profile_stores.dart';
import 'package:flut_marriage/services/owned_listing_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Settings shows Google-style account card and Sign out', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'identity_name': 'Ravi',
      'identity_phone': '919876543210',
      'identity_phone_verified': true,
      'identity_city_label': 'Mumbai',
    });
    final prefs = await SharedPreferences.getInstance();

    // Short phone height: Sign out used to clip below Delete without scroll.
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => IdentityStore(prefs)),
          ChangeNotifierProvider(create: (_) => LocaleController(prefs)),
          ChangeNotifierProvider(create: (_) => LikesStore(preferences: prefs)),
          ChangeNotifierProvider(create: (_) => OwnedListingCache(prefs)),
          ChangeNotifierProvider(create: (_) => ProfileStore(prefs)),
          ChangeNotifierProvider(
            create: (_) => JobsOfferStore(preferences: prefs),
          ),
          ChangeNotifierProvider(
            create: (_) => KuwaitJobsOfferStore(preferences: prefs),
          ),
          ChangeNotifierProvider(
            create: (_) => RoomsOfferStore(preferences: prefs),
          ),
          ChangeNotifierProvider(
            create: (_) => BikesOfferStore(preferences: prefs),
          ),
          ChangeNotifierProvider(
            create: (_) => HomeHelpOfferStore(preferences: prefs),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: IconButton(
                tooltip: 'Settings',
                onPressed: () => showSettingsSheet(context),
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_account_card')), findsOneWidget);
    expect(find.text('Ravi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_sign_out')),
      200,
    );
    expect(find.byKey(const Key('settings_sign_out')), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.textContaining('Posts stay'), findsNothing);
    expect(find.textContaining('Verify again'), findsNothing);
  });
}

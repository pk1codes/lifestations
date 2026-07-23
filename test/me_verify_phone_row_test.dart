import 'package:flut_marriage/main.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/services/seed_repository.dart';
import 'package:flut_marriage/services/share_card_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Me Account row is the only verify path when not verified', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'domain_coach_seen': true,
      'identity_name': 'Ravi',
      'identity_phone': '919869610903',
      'identity_city_id': 'mumbai',
      'identity_city_label': 'Mumbai',
      'identity_language': 'Hindi',
      'identity_phone_verified': false,
      'identity_dial_code': '91',
    });
    final prefs = await SharedPreferences.getInstance();
    final controller = DomainController(prefs);
    const seeds = SeedRepository();
    final stores = {
      for (final domain in AppDomainId.values)
        domain: DiscoveryStore(domain)..load(seeds.forDomain(domain)),
    };

    await tester.pumpWidget(
      FlutMarriageApp(
        preferences: prefs,
        domainController: controller,
        discoveryStores: stores,
        shareRepository: ShareCardRepository(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('me_account_row')), findsOneWidget);
    expect(find.text('Verify phone'), findsOneWidget);
    expect(find.byKey(const Key('me_verify_phone_row')), findsNothing);
    expect(find.byKey(const Key('me_whatsapp_needed_pill')), findsNothing);

    await tester.tap(find.byKey(const Key('me_account_row')));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsWidgets);
    expect(find.byKey(const Key('account_open_phone_verify')), findsOneWidget);
  });
}

import 'package:flut_marriage/main.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/services/seed_repository.dart';
import 'package:flut_marriage/services/share_card_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Browse title is a label; only apps square opens switcher', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'domain_coach_seen': true,
      'selected_domain': AppDomainId.marriage.index,
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

    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.apps_rounded), findsOneWidget);
    expect(find.byKey(const Key('domain_switcher')), findsOneWidget);

    // Title is not a second switcher — tapping "Marriage" text alone must not
    // open the sheet (only the apps square does).
    await tester.tap(find.byKey(const Key('domain_switcher')));
    await tester.pumpAndSettle();

    expect(find.text('Jobs'), findsWidgets);
    expect(find.text('Rooms'), findsWidgets);
    expect(find.text('Bikes'), findsWidgets);
    expect(find.byKey(const Key('domain_apps_grid')), findsOneWidget);
  });
}

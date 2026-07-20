import 'package:flut_marriage/main.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flut_marriage/services/seed_repository.dart';
import 'package:flut_marriage/services/share_card_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shell renders synthetic Marriage feed and navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'domain_coach_seen': true});
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

    expect(find.text('Marriage'), findsWidgets);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Likes'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(find.text('Guide'), findsNothing);
    expect(find.byType(DiscoveryCard), findsWidgets);

    await tester.tap(find.text('Likes'));
    await tester.pumpAndSettle();
    expect(find.text('No likes yet'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('My posts'), findsOneWidget);
    expect(find.text('Add your first post'), findsOneWidget);
    expect(find.text('Get more views'), findsNothing);
    expect(find.text('Settings & safety'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);

    // Close settings sheet.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    // Zero posts: My posts skips the empty layer and opens the new-post picker.
    await tester.tap(find.text('My posts'));
    await tester.pumpAndSettle();
    expect(find.text('New post'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('I need work / I have work'), findsOneWidget);
    expect(find.text('Lend my bike'), findsOneWidget);
    expect(find.text('Add ad'), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline), findsWidgets);
  });

  test('saved Guide tab index clamps to Me', () async {
    SharedPreferences.setMockInitialValues({
      'tab_marriage': 3,
      'domain_coach_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final controller = DomainController(prefs);
    expect(controller.selectedTab, DomainController.maxTabIndex);
  });
}

import 'package:flut_marriage/main.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/services/seed_repository.dart';
import 'package:flut_marriage/services/share_card_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Section C UI matrix — automated smoke for shell + domain switch + feeds.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
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
  }

  testWidgets('C1: apps square opens full domain grid; title not dropdown', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byKey(const Key('domain_switcher')), findsOneWidget);
    await tester.tap(find.byKey(const Key('domain_switcher')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('domain_apps_grid')), findsOneWidget);
    for (final id in AppDomainId.values) {
      expect(find.byKey(Key('domain_tile_${id.name}')), findsOneWidget);
    }
    final help = tester.getRect(find.byKey(const Key('domain_tile_homeHelp')));
    final marriage = tester.getRect(
      find.byKey(const Key('domain_tile_marriage')),
    );
    expect(help.top, greaterThan(marriage.bottom - 1));
  });

  testWidgets('C2: switch to Jobs and Rooms feeds', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('domain_switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('domain_tile_jobs')));
    await tester.pumpAndSettle();
    expect(find.text('Jobs'), findsWidgets);

    await tester.tap(find.byKey(const Key('domain_switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('domain_tile_rooms')));
    await tester.pumpAndSettle();
    expect(find.text('Rooms'), findsWidgets);
  });

  testWidgets('C2b: every enabled domain is switchable from the grid', (
    tester,
  ) async {
    await pumpApp(tester);
    for (final domain in AppDomains.all.where((d) => d.enabled)) {
      await tester.tap(find.byKey(const Key('domain_switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('domain_tile_${domain.id.name}')));
      await tester.pumpAndSettle();
      expect(find.text(domain.label), findsWidgets);
      expect(find.text('Browse'), findsOneWidget);
    }
  });

  testWidgets('C1: Likes and Me keep domain switcher', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Likes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('domain_switcher')), findsOneWidget);
    expect(find.byKey(const Key('page_domain_label')), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('domain_switcher')), findsOneWidget);
    expect(find.text('Posts'), findsOneWidget);
  });
}

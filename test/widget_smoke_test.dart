import 'package:flut_marriage/main.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flut_marriage/services/seed_repository.dart';
import 'package:flut_marriage/services/share_card_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
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
    expect(find.text('Guide'), findsOneWidget);
    expect(find.byType(DiscoveryCard), findsWidgets);

    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();
    expect(find.text('A safer way to connect'), findsOneWidget);
    expect(find.text('Contact is private'), findsOneWidget);
  });
}

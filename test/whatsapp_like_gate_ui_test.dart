import 'package:flut_marriage/main.dart';
import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/like_display.dart';
import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flut_marriage/services/seed_repository.dart';
import 'package:flut_marriage/services/share_card_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Me Account subtitle prompts Verify phone when unverified', (
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
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('me_account_row')), findsOneWidget);
    expect(find.text('Verify phone'), findsOneWidget);
    expect(find.byKey(const Key('me_whatsapp_needed_pill')), findsNothing);
  });

  testWidgets('blank like detail keeps WhatsApp and Telegram actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final likes = LikesStore();
    likes.receiveLike(
      AppDomainId.marriage,
      'peer-blank',
      card: const DiscoveryCardModel(
        id: 'peer-blank',
        domain: AppDomainId.marriage,
        ownerId: 'peer-blank',
        title: LikeDisplay.placeholderTitle,
        subtitle: '',
        cityId: '',
        cityLabel: '',
        categoryTags: <String>[],
        imageUrls: <String>[],
        attributes: <String, Object?>{'identityOnly': true},
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DomainController(prefs)),
          ChangeNotifierProvider.value(value: likes),
          ChangeNotifierProvider(create: (_) => IdentityStore(prefs)),
        ],
        child: const MaterialApp(home: Scaffold(body: LikesScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining(LikeDisplay.likedByLabel).first);
    await tester.pumpAndSettle();

    expect(find.text(LikeDisplay.yourPostLabel), findsWidgets);
    expect(find.text(LikeDisplay.likedByLabel), findsWidgets);
    expect(find.text(LikeDisplay.noPhotoYet), findsWidgets);
    expect(find.text('Accept — chat'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text(LikeDisplay.missingListing), findsWidgets);
  });
}

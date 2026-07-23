import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/like_display.dart';
import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flut_marriage/services/likes_repository.dart';
import 'package:flut_marriage/services/owned_listing_cache.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/state/domain_profile_stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineLikesRepository extends LikesRepository {
  @override
  Future<void> like({
    required AppDomainId domain,
    String? targetUid,
    DiscoveryCardModel? target,
    DiscoveryCardModel? snapshot,
    DiscoveryCardModel? fromCard,
  }) async {}
}

void main() {
  testWidgets('Likes puts Match first with empty hint and compact CTAs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final likes = LikesStore(
      preferences: prefs,
      repository: _OfflineLikesRepository(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DomainController(prefs)),
          ChangeNotifierProvider.value(value: likes),
          ChangeNotifierProvider(create: (_) => IdentityStore(prefs)),
          ChangeNotifierProvider(create: (_) => LocaleController(prefs)),
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
        child: const MaterialApp(home: Scaffold(body: LikesScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('likes_match_section')), findsOneWidget);
    expect(find.text(LikeDisplay.matchEmptyHint), findsOneWidget);

    final matchY = tester
        .getTopLeft(find.byKey(const Key('likes_match_section')))
        .dy;
    final iLikedY = tester.getTopLeft(find.text('I liked')).dy;
    final likedMeY = tester.getTopLeft(find.text('Liked me')).dy;
    expect(matchY, lessThan(iLikedY));
    expect(iLikedY, lessThan(likedMeY));
  });

  testWidgets('Match row uses primary WhatsApp and overflow delete', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'identity_phone_verified': true,
      'identity_phone': '919876543210',
      'identity_contact_share_chosen': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final likes = LikesStore(
      preferences: prefs,
      repository: _OfflineLikesRepository(),
    );
    const peer = DiscoveryCardModel(
      id: 'peer_post',
      domain: AppDomainId.marriage,
      ownerId: 'peer',
      title: 'Priya',
      subtitle: '',
      cityId: 'mumbai',
      cityLabel: 'Mumbai',
      categoryTags: <String>[],
      imageUrls: <String>[],
    );
    const mine = DiscoveryCardModel(
      id: 'mine_post',
      domain: AppDomainId.marriage,
      ownerId: 'me',
      title: 'Ravi',
      subtitle: '',
      cityId: 'mumbai',
      cityLabel: 'Mumbai',
      categoryTags: <String>[],
      imageUrls: <String>[],
    );
    likes.receiveLike(
      AppDomainId.marriage,
      'peer',
      card: peer,
      targetCard: mine,
    );
    await likes.like(AppDomainId.marriage, 'peer', snapshot: peer, fromCard: mine);

    expect(likes.matchCount, 1);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DomainController(prefs)),
          ChangeNotifierProvider.value(value: likes),
          ChangeNotifierProvider(create: (_) => IdentityStore(prefs)),
          ChangeNotifierProvider(create: (_) => LocaleController(prefs)),
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
        child: const MaterialApp(home: Scaffold(body: LikesScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('match_row_marriage_peer')), findsOneWidget);
    expect(find.byKey(const Key('match_whatsapp_btn')), findsOneWidget);
    expect(find.byKey(const Key('match_telegram_btn')), findsOneWidget);
    expect(find.byKey(const Key('match_more_marriage_peer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('match_row_marriage_peer')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('match_your_post_chip')), findsOneWidget);
    expect(
      find.byKey(const Key('match_detail_delete_marriage_peer')),
      findsOneWidget,
    );
    expect(find.text(LikeDisplay.deleteMatchLabel), findsWidgets);
    // Compact sheet: no stacked "Liked by" admin dual-hero labels.
    expect(find.text(LikeDisplay.likedByLabel), findsNothing);
  });
}

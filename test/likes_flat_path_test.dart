import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/like_display.dart';
import 'package:flut_marriage/screens/home_shell.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flut_marriage/widgets/expandable_domain_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

DiscoveryCardModel _card({
  required AppDomainId domain,
  required String id,
  String title = LikeDisplay.placeholderTitle,
}) {
  return DiscoveryCardModel(
    id: id,
    domain: domain,
    ownerId: id,
    title: title,
    subtitle: '',
    cityId: '',
    cityLabel: '',
    categoryTags: const <String>[],
    imageUrls: const <String>[],
  );
}

void main() {
  testWidgets('Likes domain sections collapse and expand', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final likes = LikesStore(preferences: prefs);
    likes.receiveLike(
      AppDomainId.jobs,
      'peer1',
      card: _card(domain: AppDomainId.jobs, id: 'peer1'),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DomainController(prefs)),
          ChangeNotifierProvider.value(value: likes),
        ],
        child: const MaterialApp(home: Scaffold(body: LikesScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byType(ExpandableDomainSection), findsOneWidget);
    expect(find.byKey(const Key('likes_domain_jobs')), findsOneWidget);
    expect(find.textContaining(LikeDisplay.likedByLabel), findsOneWidget);
    expect(find.textContaining(LikeDisplay.yourPostLabel), findsOneWidget);

    await tester.tap(find.byKey(const Key('domain_section_header_jobs')));
    await tester.pumpAndSettle();
    expect(find.textContaining(LikeDisplay.likedByLabel), findsNothing);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.byKey(const Key('domain_section_header_jobs')));
    await tester.pumpAndSettle();
    expect(find.textContaining(LikeDisplay.likedByLabel), findsOneWidget);
  });

  testWidgets('Remove clears Liked me row and Undo restores it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final likes = LikesStore(preferences: prefs);
    likes.receiveLike(
      AppDomainId.marriage,
      'peer-rm',
      card: _card(domain: AppDomainId.marriage, id: 'peer-rm'),
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

    expect(likes.inboundCount, 1);
    await tester.tap(
      find.byKey(const Key('like_remove_inbound_marriage_peer-rm')),
    );
    await tester.pumpAndSettle();
    expect(likes.inboundCount, 0);
    expect(find.text(LikeConsent.removedSnack), findsOneWidget);

    await tester.tap(find.text(LikeConsent.undo));
    await tester.pumpAndSettle();
    expect(likes.inboundCount, 1);
  });

  test('dismissInbound persists and filters counts', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final likes = LikesStore(preferences: prefs);
    likes.receiveLike(
      AppDomainId.bikes,
      'rider',
      card: _card(domain: AppDomainId.bikes, id: 'rider'),
    );
    expect(likes.inboundCount, 1);
    await likes.dismissInbound(AppDomainId.bikes, 'rider');
    expect(likes.inboundCount, 0);
    expect(likes.inboundEntries(AppDomainId.bikes), isEmpty);

    final again = LikesStore(preferences: prefs);
    again.receiveLike(
      AppDomainId.bikes,
      'rider',
      card: _card(domain: AppDomainId.bikes, id: 'rider'),
    );
    expect(again.inboundCount, 0);
  });
}

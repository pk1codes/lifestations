import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/like_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder likes never show Someone', () {
    expect(LikeDisplay.rowTitle(null), LikeDisplay.placeholderTitle);
    expect(
      LikeDisplay.rowTitle(
        const DiscoveryCardModel(
          id: 'a',
          domain: AppDomainId.marriage,
          ownerId: 'u',
          title: 'Someone',
          subtitle: '',
          cityId: '',
          cityLabel: '',
          categoryTags: <String>[],
          imageUrls: <String>[],
        ),
      ),
      'Liked',
    );
    expect(
      LikeDisplay.rowTitle(
        const DiscoveryCardModel(
          id: 'a',
          domain: AppDomainId.marriage,
          ownerId: 'u',
          title: 'Liked post',
          subtitle: '',
          cityId: '',
          cityLabel: '',
          categoryTags: <String>[],
          imageUrls: <String>[],
        ),
      ),
      'Liked',
    );
    expect(LikeDisplay.missingListing, 'Listing not ready');
    expect(
      LikeDisplay.placeholderTitle.toLowerCase(),
      isNot(contains('someone')),
    );
  });

  test('real listing titles stay intact', () {
    final card = DiscoveryCardModel(
      id: 'a',
      domain: AppDomainId.jobs,
      ownerId: 'u',
      title: 'Driver',
      subtitle: 'I have',
      cityId: 'mumbai',
      cityLabel: 'Mumbai',
      categoryTags: const <String>['Driver'],
      imageUrls: const <String>['https://example.com/a.jpg'],
      role: 'seek',
      attributes: const <String, Object?>{'tradeId': 'Driver'},
    );
    expect(LikeDisplay.isPlaceholderCard(card), isFalse);
    expect(LikeDisplay.rowTitle(card), isNot(equals('Liked')));
    expect(
      LikeDisplay.rowTitle(card).toLowerCase(),
      isNot(contains('someone')),
    );
  });
}

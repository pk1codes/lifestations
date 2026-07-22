import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/models/public_share_card.dart';
import 'package:flut_marriage/services/listing_publisher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('jobs share payload includes detailLine and sideLabel for rules', () {
    final publisher = ListingPublisher();
    final card = publisher.buildJobsCard(
      ownerId: 'uid1',
      offerId: 'jobs_share_1',
      profile: const JobsProfile(
        role: 'seek',
        tradeId: 'Driver',
        cityId: 'mumbai',
        salaryBand: '₹15–25k',
        photoCount: 1,
      ),
      photoUrls: const ['https://example.com/a.jpg'],
    );
    final share = PublicShareCard.fromDiscovery(card, slug: 'jobs_abcdefghij');
    final json = share.toFirestore();
    expect(json['sideLabel'], 'I have');
    expect(json['detailLine'], isNotEmpty);
    expect(json.keys, everyElement(isIn(PublicShareCard.allowlist)));
  });

  test('firestore rules allowlist includes detailLine and sideLabel', () {
    // Source contract — keeps client + rules in sync.
    expect(PublicShareCard.allowlist.contains('detailLine'), isTrue);
    expect(PublicShareCard.allowlist.contains('sideLabel'), isTrue);
  });
}

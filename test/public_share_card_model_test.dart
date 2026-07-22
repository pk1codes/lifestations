import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/public_share_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromDiscovery never copies free-text title or bio-like fields', () {
    const card = DiscoveryCardModel(
      id: 'x1',
      domain: AppDomainId.marriage,
      ownerId: 'owner1',
      title: 'Real Person Name Secret',
      subtitle: 'Call me on WhatsApp 9999999999',
      cityId: 'mumbai',
      cityLabel: 'Mumbai & MMR',
      categoryTags: ['intentional'],
      imageUrls: ['initial_seeds/photos/marriage_1_1.webp'],
      ageBand: '25-29',
    );
    final share = PublicShareCard.fromDiscovery(
      card,
      slug: 'marriage_abcdef123456',
    );
    final json = share.toFirestore();
    expect(json.keys.every(PublicShareCard.allowlist.contains), isTrue);
    for (final key in PublicShareCard.forbidden) {
      expect(json.containsKey(key), isFalse);
    }
    expect(json['headline'], isNot(contains('Real Person')));
    expect(json['headline'], isNot(contains('9999999999')));
    expect(json['headline'], '25-29');
    expect(json['locationLabel'], 'Mumbai & MMR');
  });

  test('slug parsing and validation', () {
    expect(PublicShareCard.domainFromSlug('jobs_abc123xyz'), AppDomainId.jobs);
    expect(
      PublicShareCard.domainFromSlug('home_help_abc123xyz'),
      AppDomainId.homeHelp,
    );
    expect(PublicShareCard.isValidSlug('marriage_abcdef'), isTrue);
    expect(PublicShareCard.isValidSlug('bad'), isFalse);
  });

  test('fromFirestore rejects forbidden or unknown keys', () {
    expect(
      PublicShareCard.fromFirestore('marriage_abcdef', {
        'slug': 'marriage_abcdef',
        'active': true,
        'ownerId': 'o',
        'domain': 'marriage',
        'sourceId': 's',
        'headline': 'Marriage · Mumbai',
        'bio': 'secret',
      }),
      isNull,
    );
  });
}

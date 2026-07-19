import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/services/share_card_repository.dart';
import 'package:flut_marriage/services/share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serialized share payload has no PII keys', () async {
    final repo = ShareCardRepository();
    const card = DiscoveryCardModel(
      id: 'offer1',
      domain: AppDomainId.jobs,
      ownerId: 'owner',
      title: 'Asha Sharma Driver',
      subtitle: 'WhatsApp 9812345678',
      cityId: 'delhi',
      cityLabel: 'Delhi NCR',
      categoryTags: ['driver'],
      imageUrls: [],
      role: 'seek',
    );
    final published = await repo.createOrUpdate(card);
    final payload = published.toFirestore();
    expect(payload['headline'], isNot(contains('Asha')));
    expect(
      payload.values.map((v) => '$v').join(' '),
      isNot(contains('9812345678')),
    );
    expect(payload.containsKey('whatsappNumber'), isFalse);
    expect(payload.containsKey('displayName'), isFalse);
    expect(ShareService(repo).canonicalUrl(published.slug), contains('/c/'));
  });
}

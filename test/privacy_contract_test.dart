import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/services/likes_repository.dart';
import 'package:flut_marriage/state/app_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('public document privacy', () {
    test('safe cards omit private contact', () {
      const card = DiscoveryCardModel(
        id: 'card',
        domain: AppDomainId.jobs,
        ownerId: 'owner',
        title: 'Driver available',
        subtitle: 'Looking for driver work',
        cityId: 'mumbai',
        cityLabel: 'Mumbai & MMR',
        categoryTags: ['driver'],
        imageUrls: [],
      );
      final json = card.toPublicJson();
      expect(DiscoveryCardModel.isPublicSafe(json), isTrue);
      for (final key in DiscoveryCardModel.forbiddenPublicKeys) {
        expect(json.containsKey(key), isFalse);
      }
    });

    test('nested contact and vehicle document URLs are rejected', () {
      expect(
        DiscoveryCardModel.isPublicSafe({
          'attributes': {'whatsappNumber': '9999999999'},
        }),
        isFalse,
      );
      expect(
        DiscoveryCardModel.isPublicSafe({
          'attributes': {'insuranceUrl': 'https://private.invalid/document'},
        }),
        isFalse,
      );
    });
  });

  group('contact unlock', () {
    test(
      'requires same-domain mutual like and verified non-anonymous user',
      () async {
        final likes = LikesStore(repository: _OfflineLikesRepository());
        await likes.like(AppDomainId.jobs, 'other');
        likes.receiveLike(AppDomainId.jobs, 'other');
        expect(
          likes.canUnlock(
            domain: AppDomainId.jobs,
            otherId: 'other',
            anonymous: false,
            phoneVerified: true,
          ),
          isTrue,
        );
        expect(
          likes.canUnlock(
            domain: AppDomainId.jobs,
            otherId: 'other',
            anonymous: true,
            phoneVerified: true,
          ),
          isFalse,
        );
        expect(
          likes.canUnlock(
            domain: AppDomainId.marriage,
            otherId: 'other',
            anonymous: false,
            phoneVerified: true,
          ),
          isFalse,
        );
      },
    );
  });

  test('identity validation trims intent and requires eight phone digits', () {
    expect(
      const Identity(
        displayName: 'A',
        whatsappNumber: '12345678',
        cityId: 'mumbai',
        nativeLanguage: 'Hindi',
      ).isValid,
      isFalse,
    );
    expect(
      const Identity(
        displayName: 'Demo User',
        whatsappNumber: '1234567',
        cityId: 'mumbai',
        nativeLanguage: 'Hindi',
      ).isValid,
      isFalse,
    );
  });
}

/// Skips Firestore so mutual-gate unit tests can seed outbound locally.
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

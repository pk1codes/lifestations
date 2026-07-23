import 'dart:io';

import 'package:flut_marriage/models/app_domain.dart';
import 'package:flut_marriage/models/discovery_card.dart';
import 'package:flut_marriage/models/domain_profiles.dart';
import 'package:flut_marriage/models/public_share_card.dart';
import 'package:flut_marriage/services/listing_publisher.dart';
import 'package:flut_marriage/services/moderation/moderation_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Automated mapping of Section B security checklist items that can be
/// proven without live staging accounts (rules source + client contracts).
void main() {
  late String firestoreRules;
  late String storageRules;
  late String functionsSrc;

  setUpAll(() {
    firestoreRules = File('firebase/firestore.rules').readAsStringSync();
    storageRules = File('firebase/storage.rules').readAsStringSync();
    functionsSrc = File('firebase/functions/index.js').readAsStringSync();
  });

  group('B1 Auth & identity', () {
    test('discovery reads require signed-in auth', () {
      expect(
        firestoreRules.contains(
          'allow read: if isSignedIn() && allowedDomain(domainId)',
        ),
        isTrue,
      );
    });

    test('OTP cooldown is 60 seconds', () {
      expect(
        firestoreRules.contains(
          "request.time > resource.data.lastSentAt + duration.value(60, 's')",
        ),
        isTrue,
      );
    });

    test('unlockContact and deleteAccount enforce App Check', () {
      expect(functionsSrc.contains('exports.unlockContact'), isTrue);
      expect(functionsSrc.contains('exports.deleteAccount'), isTrue);
      expect(functionsSrc.contains('enforceAppCheck: true'), isTrue);
    });
  });

  group('B2 Contact vault', () {
    test('vault client read is owner-only; unlock is callable', () {
      final vault = firestoreRules
          .split('match /private/{docId}')[1]
          .split('match /blocks')[0];
      expect(vault.contains('allow read: if isOwner(userId);'), isTrue);
      expect(vault.contains('mutualLike(userId)'), isFalse);
      expect(functionsSrc.contains('exports.unlockContact'), isTrue);
    });

    test('public listing builders omit contact fields', () {
      final card = ListingPublisher().buildJobsCard(
        ownerId: 'u1',
        offerId: 'jobs_sec',
        profile: const JobsProfile(
          role: 'seek',
          tradeId: 'Driver',
          cityId: 'mumbai',
          salaryBand: 'Prefer not to say',
          photoCount: 1,
        ),
        photoUrls: const ['https://cdn.example/j.webp'],
      );
      final json = card.toPublicJson();
      expect(DiscoveryCardModel.isPublicSafe(json), isTrue);
      expect(json.containsKey('whatsappNumber'), isFalse);
      expect(json.containsKey('phone'), isFalse);
      expect(json.containsKey('name'), isFalse);
    });
  });

  group('B3 Listings paths', () {
    test('Marriage profiles; Jobs/Rooms/Bikes/Help/Kuwait Jobs offers', () {
      expect(AppDomains.marriage.collection, 'domains/marriage/profiles');
      expect(AppDomains.jobs.collection, 'domains/jobs/offers');
      expect(AppDomains.rooms.collection, 'domains/rooms/offers');
      expect(AppDomains.bikes.collection, 'domains/bikes/offers');
      expect(AppDomains.homeHelp.collection, 'domains/home_help/offers');
      expect(AppDomains.kuwaitJobs.collection, 'domains/kuwait_jobs/offers');
    });

    test('Jobs demand requires howMany; supply requires photo', () {
      expect(
        const JobsProfile(
          role: 'offer',
          tradeId: 'Security',
          cityId: 'mumbai',
          salaryBand: 'Prefer not to say',
          howMany: '3',
        ).isValid,
        isTrue,
      );
      expect(
        const JobsProfile(
          role: 'offer',
          tradeId: 'Security',
          cityId: 'mumbai',
          salaryBand: 'Prefer not to say',
        ).isValid,
        isFalse,
      );
      expect(
        const JobsProfile(
          role: 'seek',
          tradeId: 'Driver',
          cityId: 'mumbai',
          salaryBand: 'Prefer not to say',
          photoCount: 0,
        ).isValid,
        isFalse,
      );
    });

    test('rules allow Jobs in validOffer domains', () {
      final offerFn = firestoreRules
          .split('function validOffer')[1]
          .split('function validPublicCard')[0];
      expect(offerFn.contains("'jobs'"), isTrue);
    });
  });

  group('B4 Storage', () {
    test('docs path owner-only; 5 MiB; image MIME', () {
      expect(storageRules.contains('5 * 1024 * 1024'), isTrue);
      expect(storageRules.contains("image/(webp|jpeg|jpg|png)"), isTrue);
      expect(
        storageRules.contains(
          'match /media/{userId}/{domainId}/{offerId}/docs/{docName}/{fileName}',
        ),
        isTrue,
      );
    });

    test('Jobs media path allowed under offers media', () {
      expect(
        storageRules.contains(
          "domainId in ['rooms', 'bikes', 'home_help', 'jobs', 'kuwait_jobs']",
        ),
        isTrue,
      );
    });
  });

  group('B5 Moderation', () {
    test('text safety blocks disallowed terms', () {
      final result = const TextSafetyScanner().scan('nude');
      expect(result.safe, isFalse);
    });

    test('image_flags are create-only / unreadable', () {
      expect(
        RegExp(
          r'match /image_flags/\{flagId\}[\s\S]*?allow read: if false;',
        ).hasMatch(firestoreRules),
        isTrue,
      );
    });
  });

  group('B7 Public share', () {
    test('share allowlist excludes contact and free-form bio', () {
      expect(PublicShareCard.allowlist.contains('headline'), isTrue);
      expect(PublicShareCard.allowlist.contains('detailLine'), isTrue);
      expect(PublicShareCard.allowlist.contains('sideLabel'), isTrue);
      expect(PublicShareCard.allowlist.contains('whatsappNumber'), isFalse);
      expect(PublicShareCard.allowlist.contains('bio'), isFalse);
      expect(PublicShareCard.allowlist.contains('name'), isFalse);
    });
  });
}
